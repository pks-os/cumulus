require "autoscaling/models/GroupConfig"
require "autoscaling/models/PolicyConfig"
require "common/BaseLoader"
require "conf/Configuration"

module Cumulus
  module AutoScaling
    # Public: Load AutoScaling assets
    module Loader
      include Common::BaseLoader

      @@groups_dir = Configuration.instance.autoscaling.groups_directory
      @@group_loader = Proc.new { |name, json| GroupConfig.new(name, json) }
      @@static_dir = Configuration.instance.autoscaling.static_policy_directory
      @@template_dir = Configuration.instance.autoscaling.template_policy_directory
      @@policy_loader = Proc.new { |name, json| PolicyConfig.new(json) }

      # Public: Load all autoscaling group configurations as GroupConfig objects
      #
      # Returns an array of GroupConfig objects
      def Loader.groups
        Common::BaseLoader.resources(@@groups_dir, &@@group_loader)
      end

      # Public: Load a single autoscaling group configuration as a GroupConfig
      # object
      #
      # file - the name of the file the configuration is located in
      #
      # Returns the corresponding GroupConfig object
      def Loader.group(file)
        Common::BaseLoader.resource(file, @@groups_dir, &@@group_loader)
      end

      # Public: Load a static scaling policy
      #
      # file - the file the policy definition is found in
      #
      # Returns a PolicyConfig object that contains the configuration
      def Loader.static_policy(file)
        Common::BaseLoader.resource(file, @@static_dir, &@@policy_loader)
      end

      # Public: Load a template scaling policy
      #
      # file - the file the template definition is found in
      # variables - a Hash of variables to apply to the template
      #
      # Returns a PolicyConfig object corresponding to the applied template
      def Loader.template_policy(file, variables)
        Common::BaseLoader.template(file, @@template_dir, variables, &@@policy_loader)
      end

    end
  end
end
