window.onscroll = function() {
  var scroll = document.getElementById('scroll-to-top');
  if (window.scrollY > 20 && scroll.className.indexOf(' visible') == -1) {
    scroll.className += ' visible'
  } else if (window.scrollY <= 20 && scroll.className.indexOf(' visible') != -1) {
    scroll.className = scroll.className.replace(' visible', '')
  }
}

function scrollingOnload() {
  document.getElementById('scroll-to-top').addEventListener('click', function(e) {
    var scroller = document.documentElement
    if (!document.documentElement.scrollTop) {
      scroller = document.body
    }
    e.preventDefault()
    animate(scroller, 'scrollTop', '', window.scrollY, 0, 1000, true);
  })
}

if (window.onload) {
  var current = window.onload;
  window.onload = function() {
    current();
    scrollingOnload();
  }
} else {
  window.onload = scrollingOnload;
}


// copied from http://stackoverflow.com/questions/17733076/smooth-scroll-anchor-links-without-jquery
function animate(elem,style,unit,from,to,time,prop) {
    if( !elem) return;
    var start = new Date().getTime(),
        timer = setInterval(function() {
            var step = Math.min(1,(new Date().getTime()-start)/time);
            if (prop) {
                elem[style] = (from+step*(to-from))+unit;
            } else {
                elem.style[style] = (from+step*(to-from))+unit;
            }
            if( step == 1) clearInterval(timer);
        },25);
    elem.style[style] = from+unit;
}
