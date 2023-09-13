window.queueOnReady(function() {
    $('input#dob_enabled').on('change', function() {
        if ($(this).is(':checked')) {
            $('select#employee_dob_1i, select#employee_dob_2i, select#employee_dob_3i').show();
        } else {
            $('select#employee_dob_1i, select#employee_dob_2i, select#employee_dob_3i').hide();
        }
    });
});
