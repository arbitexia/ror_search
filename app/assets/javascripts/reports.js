window.queueOnReady(function() {
    $('.print-report-link').click(function() {
        var employeesMask = $('input[name="employees_to_print[]"]:checked').toArray().map(function(el) {
            return parseInt($(el).val());
        }).join(",");

        var vendorsMask = $('input[name="vendors_to_print[]"]:checked').toArray().map(function(el) {
            return parseInt($(el).val());
        }).join(",");

        if (employeesMask.length === 0 && vendorsMask.length === 0) {
            window.print();
        } else {
            var separator = window.location.toString().indexOf("?") === -1 ? "?" : "&";

            var location = window.location.toString() + separator + "masked=yes";

            if (employeesMask.length > 0) {
                location += "&employees_mask=" + employeesMask;
            }

            if (vendorsMask.length > 0) {
                location += "&vendors_mask=" + vendorsMask;
            }

            $('<iframe/>').width(0).height(0).css('border-width', 0).attr('src', location).appendTo('body');
        }
    });

    $('.print-pre-letter, .print-letter').click(function() {
        var url = $(this).data('url');
        $('<iframe/>').width(0).height(0).css('border-width', 0).attr('src', url).appendTo('body');
    });

    $('.print-summary').click(function() {
        var url = $(this).data('url');
        var $iframe = $('<iframe/>').width(0).height(0).css('border-width', 0).attr('src', url).appendTo('body');

        var iframe = $iframe.get(0);
        iframe.onload = function() {
            setTimeout(function () {
                iframe.focus();
                iframe.contentWindow.print();
            }, 1);
        };
    });

    $('.print-report-employees-link').click(function() {
        var employeesMask = $('input[name="employees_to_print[]"]').toArray().map(function(el) {
            return parseInt($(el).val());
        }).join(",");
        var separator = window.location.toString().indexOf("?") === -1 ? "?" : "&";
        var location = window.location.toString() + separator + "masked=yes";
        location += "&employees_mask=" + employeesMask;
        $('<iframe/>').width(0).height(0).css('border-width', 0).attr('src', location).appendTo('body');
    });

    $('.print-report-vendors-link').click(function() {
        var vendorsMask = $('input[name="vendors_to_print[]"]').toArray().map(function(el) {
            return parseInt($(el).val());
        }).join(",");
        var separator = window.location.toString().indexOf("?") === -1 ? "?" : "&";
        var location = window.location.toString() + separator + "masked=yes";
        location += "&vendors_mask=" + vendorsMask;
        $('<iframe/>').width(0).height(0).css('border-width', 0).attr('src', location).appendTo('body');
    });
});