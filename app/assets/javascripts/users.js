window.queueOnReady(function () {
    $('select[name="user[client_ids][]"]').select2({
        multiple: true,
        width: 400
    });
});