function onSelectMes(mes) {
    if (mes) {
        var url = new URL(window.location.href);
        url.searchParams.set('mes', mes);
        window.location.href = url.toString();
    }
}

function replicarValor(fieldName) {
    var inputs = document.getElementsByClassName(fieldName);
    if (inputs.length > 0) {
        var value = inputs[0].value;
        for (var i = 1; i < inputs.length; i++) {
            inputs[i].value = value;
        }
    }
}
