window.readyFunctions = [];

window.ncReady = function () {
    window.readyFunctions.forEach(function (fn) {
        fn();
    });
};

window.queueOnReady = function (fn) {
    window.readyFunctions.push(fn);
};

$(document).ready(function () {
    // window.ncReady();

    $(document).on('turbolinks:load', function () {
        window.ncReady();
    });
});
