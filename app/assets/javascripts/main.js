window.queueOnReady(function() {
    $('a.smoothscroll').each(function() {
        var selector = $(this).attr('href');
        $(this).attr('href', '');

        $(this).click(function(e) {
            $(selector).animatescroll();
            return false;
        });
    });
});