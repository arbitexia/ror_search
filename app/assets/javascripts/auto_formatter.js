window.queueOnReady(function() {
    $('input[data-pattern]').each(function(index, elem) {
        $(elem).formatter({
            pattern: $(elem).data('pattern'),
            persistent: false
        }).blur();

        window.scrollTo(0, 0);
    });
});
