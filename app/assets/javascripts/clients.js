window.queueOnReady(function () {
    if ($('input[name="client[client_type]"]').length > 0) {
        function updateClientType() {
            var type = $('input[name="client[client_type]"]:checked').val();
            var humanType = type.substring(0, 1).toUpperCase() + type.substring(1);

            //     $('input[type="submit"]').val('Update ' + humanType);

            if (type == 'facility') {
                $('.parent-container').show();
                $('.company-only').hide();
                $('.facility-only').show();
            } else {
                $('.parent-container').hide();
                $('.company-only').show();
                $('.facility-only').hide();
            }

            // $('.client_type_field').hide();
        }

        updateClientType();
        $('input[name="client[client_type]"]').change(updateClientType);
    }

    function updateBillingFields() {
        if ($('input[name="client[billing_same_as_mailing]"]').is(':checked')) {
            $('.billing').hide();
        } else {
            $('.billing').show();
        }
    }

    $('input[name="client[billing_same_as_mailing]"]').change(updateBillingFields);
    updateBillingFields();

    $('select[name="client[isolved_client_id]"]').select2({
        width: 200,
        ajax: {
            url: '/isolved/search_clients',
            data: function (params) {
                return {
                    endpoint: $('#client_isolved_endpoint').val(),
                    page: params.page || 0,
                    query: params.term
                };
            },
            processResults: function(data) {
                var results = data.results.map(function(result) {
                    return { id: result.id, text: result.clientName }
                });
                var emptyResult = { id: "0", text: "None" };
                results = [emptyResult].concat(results);
                return {
                    pagination: data.pagination,
                    results: results
                }
            }
        }
    }).on('select2:select', function (e) {
        // window.$e = e;
        var clientName = e.params.data.text;
        $('input[name="client[isolved_client_name]"]').val(clientName);
    });

    $('select[name="client[isolved_legal_company_id]"]').select2({
        width: 200,
        ajax: {
            url: '/isolved/search_legal_companies',
            data: function (params) {
                return {
                    sanction_search_client_id: $('select[name="client[parent_id]"]').val(),
                    query: params.term
                };
            },
            processResults: function(data) {
                var results = data.results.map(function(result) {
                    return { id: result.id, text: result.legalName }
                });
                var emptyResult = { id: "0", text: "None" };
                results = [emptyResult].concat(results);
                return {
                    pagination: data.pagination,
                    results: results
                }
            }
        }
    }).on('select2:select', function (e) {
        // window.$e = e;
        var clientName = e.params.data.text;
        $('input[name="client[isolved_legal_company_name]"]').val(clientName);
    });

    $('select[name="client[isolved_location_id]"]').select2({
        width: 200,
        ajax: {
            url: '/isolved/search_locations',
            data: function (params) {
                return {
                    sanction_search_client_id: $('select[name="client[parent_id]"]').val(),
                    legal_id: $('select[name="client[isolved_legal_company_id]"]').val(),
                    query: params.term
                };
            },
            processResults: function(data) {
                var results = data.results.map(function(result) {
                    return { id: result.id, text: result.workLocationDescription }
                });
                var emptyResult = { id: "0", text: "None" };
                results = [emptyResult].concat(results);
                return {
                    pagination: data.pagination,
                    results: results
                }
            }
        }
    }).on('select2:select', function (e) {
        // window.$e = e;
        var clientName = e.params.data.text;
        $('input[name="client[isolved_location_name]"]').val(clientName);
    });
});
