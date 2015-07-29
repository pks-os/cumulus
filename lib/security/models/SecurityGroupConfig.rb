require "conf/Configuration"
require "security/models/RuleConfig"
require "security/models/RuleDiff"
require "security/models/RuleMigration"
require "security/models/SecurityGroupDiff"

require "json"

# Public: An object representing configuration for a security group
class SecurityGroupConfig

  attr_reader :description
  attr_reader :inbound
  attr_reader :name
  attr_reader :outbound
  attr_reader :tags
  attr_reader :vpc_id

  # Public: Constructor.
  #
  # name - the name of the security group
  # json - a hash containing the JSON configuration for the security group
  def initialize(name, json = nil)
    @name = name
    if !json.nil?
      @description = if !json["description"].nil? then json["description"] else "" end
      @vpc_id = json["vpc-id"]
      @tags = if !json["tags"].nil? then json["tags"] else {} end
      @inbound = json["rules"]["inbound"].map(&RuleConfig.method(:expand_ports)).flatten
      @outbound = if !json["rules"]["outbound"].nil?
        json["rules"]["outbound"].map(&RuleConfig.method(:expand_ports)).flatten
      else
        if Configuration.instance.security.outbound_default_all_allowed
          [RuleConfig.allow_all]
        else
          []
        end
      end
    end
  end

  # Public: Produce an array of the differences between this local configuration and the
  # configuration in AWS
  #
  # aws - the aws resource
  # sg_ids_to_names - a mapping of security group ids to their names
  #
  # Returns an array of the SecurityGroupDiffs that were found
  def diff(aws, sg_ids_to_names)
    diffs = []

    if @description != aws.description
      diffs << SecurityGroupDiff.new(SecurityGroupChange::DESCRIPTION, aws, self)
    end
    if @vpc_id != aws.vpc_id
      diffs << SecurityGroupDiff.new(SecurityGroupChange::VPC_ID, aws, self)
    end
    if @tags != Hash[aws.tags.map { |t| [t.key, t.value] }]
      diffs << SecurityGroupDiff.new(SecurityGroupChange::TAGS, aws, self)
    end

    inbound_diffs = diff_rules(@inbound, aws.ip_permissions, sg_ids_to_names)
    if !inbound_diffs.empty?
      diffs << SecurityGroupDiff.inbound(aws, self, inbound_diffs)
    end

    outbound_diffs = diff_rules(@outbound, aws.ip_permissions_egress, sg_ids_to_names)
    if !outbound_diffs.empty?
      diffs << SecurityGroupDiff.outbound(aws, self, outbound_diffs)
    end

    diffs
  end

  # Public: Populate this SecurityGroupConfig from an AWS resource
  #
  # aws             - the aws resource
  # sg_ids_to_names - a mapping of security group ids to their names
  def populate(aws, sg_ids_to_names)
    @description = aws.description
    @vpc_id = aws.vpc_id
    @tags = Hash[aws.tags.map { |t| [t.key, t.value] }]
    @inbound = combine_rules(aws.ip_permissions.map { |rule| RuleConfig.from_aws(rule, sg_ids_to_names) })
    @outbound = combine_rules(aws.ip_permissions_egress.map { |rule| RuleConfig.from_aws(rule, sg_ids_to_names) })
  end

  # Public: Get the config as a prettified JSON string.
  #
  # Returns the JSON string
  def pretty_json
    JSON.pretty_generate({
      "description" => @description,
      "vpc-id" => @vpc_id,
      "tags" => @tags,
      "rules" => {
        "inbound" => @inbound.map(&:hash).each { |r| if r["protocol"] == "-1" then r["protocol"] = "all" end },
        "outbound" => @outbound.map(&:hash).each { |r| if r["protocol"] == "-1" then r["protocol"] = "all" end }
      }
    }.reject { |k, v| v.nil? })
  end

  private

  # Internal: Determine changes in rules
  #
  # local_rules     - the rules defined locally
  # aws_rules       - the rules in AWS
  # sg_ids_to_names - a mapping of security group ids to their names
  #
  # Returns an array of RuleDiffs that represent differences between local and AWS configuration
  def diff_rules(local_rules, aws_rules, sg_ids_to_names)
    diffs = []

    # get the aws config into a format that mirrors cumulus so we can compare
    aws = aws_rules.map do |rule|
      RuleConfig.from_aws(rule, sg_ids_to_names)
    end
    aws_hashes = aws.flat_map(&:hash)
    local_hashes = local_rules.flat_map(&:hash)

    diffs << local_hashes.reject { |i| aws_hashes.include?(i) }.map { |l| RuleDiff.added(RuleConfig.new(l)) }
    diffs << aws_hashes.reject { |a| local_hashes.include?(a) }.map { |a| RuleDiff.removed(RuleConfig.new(a)) }

    diffs.flatten
  end

  # Internal: Combine rules that have the same ports and security groups to create the compact version
  # used by cumulus config.
  #
  # rules - an array of the rules to combine
  #
  # Returns an array of compact rules
  def combine_rules(rules)
    # first we find the ones that have the same protocol and port
    rules.map(&RuleMigration.method(:from_rule_config)).group_by do |rule|
      [rule.protocol, rule.ports]
    # next, we combine the matching rules together
    end.flat_map do |ignored, matches|
      if matches.size == 1
        matches
      else
        matches[1..-1].inject(matches[0]) { |prev, cur| prev.combine_allowed(cur) }
      end
    # now, try to find ones that have the same groups of allowed entities and protocol
    end.group_by do |rule|
      [rule.protocol, rule.security_groups, rule.subnets]
    # finally, we'll combine ports for the matches
    end.flat_map do |ignored, matches|
      if matches.size == 1
        matches
      else
        matches[1..-1].inject(matches[0]) { |prev, cur| prev.combine_ports(cur) }
      end
    end
  end
end
