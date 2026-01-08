var WebcamCapture = (function() {

    function init(inputId) {
        var photoInput = document.getElementById(inputId);
        if (!photoInput) {
            // Try searching by name if ID is not found
            var inputs = document.getElementsByName(inputId);
            if (inputs.length > 0) {
                photoInput = inputs[0];
            } else {
                 console.log('WebcamCapture: Input ' + inputId + ' not found.');
                 return;
            }
        }

        // Check if container already exists to avoid duplicates
        if (document.getElementById('webcam-container-' + inputId)) {
            return;
        }

        // State variables for this specific instance
        var stream = null;
        var video = document.createElement('video');
        var canvas = document.createElement('canvas');
        var container = document.createElement('div');

        container.id = 'webcam-container-' + inputId;
        container.style.display = 'none';
        container.style.marginTop = '10px';
        container.style.marginBottom = '10px';
        container.style.border = '1px solid #ccc';
        container.style.padding = '10px';
        container.style.width = '320px';
        container.style.maxWidth = '100%';
        container.style.textAlign = 'center';

        video.setAttribute('autoplay', '');
        video.setAttribute('playsinline', '');
        video.style.width = '100%';
        video.style.height = 'auto';

        canvas.style.display = 'none';

        var controls = document.createElement('div');
        controls.style.marginTop = '5px';

        var btnCapture = document.createElement('button');
        btnCapture.type = 'button';
        btnCapture.innerText = 'Capturar';
        btnCapture.className = 'botaolistagem';
        btnCapture.style.marginRight = '5px';

        var btnCancel = document.createElement('button');
        btnCancel.type = 'button';
        btnCancel.innerText = 'Cancelar';
        btnCancel.className = 'botaolistagem';

        controls.appendChild(btnCapture);
        controls.appendChild(btnCancel);

        container.appendChild(video);
        container.appendChild(canvas);
        container.appendChild(controls);

        // Append container after the file input
        photoInput.parentNode.insertBefore(container, photoInput.nextSibling);

        // Add "Take Photo" button
        var btnStart = document.createElement('button');
        btnStart.type = 'button';
        btnStart.innerText = '📷 Tirar foto com a câmera';
        btnStart.className = 'botaolistagem';
        btnStart.style.display = 'block';
        btnStart.style.marginTop = '5px';

        photoInput.parentNode.insertBefore(btnStart, container);

        // Functions
        function start() {
            container.style.display = 'block';
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                navigator.mediaDevices.getUserMedia({ video: true })
                    .then(function(s) {
                        stream = s;
                        video.srcObject = stream;
                        video.play();
                    })
                    .catch(function(err) {
                        console.error("An error occurred: " + err);
                        alert('Não foi possível acessar a câmera. Verifique se você deu permissão.');
                        container.style.display = 'none';
                    });
            } else {
                alert('Seu navegador não suporta acesso à câmera.');
                container.style.display = 'none';
            }
        }

        function stop() {
            if (stream) {
                stream.getTracks().forEach(function(track) {
                    track.stop();
                });
                stream = null;
            }
            container.style.display = 'none';
        }

        function capture() {
            if (!stream) return;

            var width = video.videoWidth;
            var height = video.videoHeight;

            canvas.width = width;
            canvas.height = height;
            canvas.getContext('2d').drawImage(video, 0, 0, width, height);

            canvas.toBlob(function(blob) {
                if (blob.size > 2 * 1024 * 1024) {
                    alert('A imagem capturada é muito grande (maior que 2MB). Tente ajustar a resolução da câmera ou iluminação.');
                    return;
                }

                var file = new File([blob], "webcam_capture.jpg", { type: "image/jpeg" });

                var dataTransfer = new DataTransfer();
                dataTransfer.items.add(file);
                photoInput.files = dataTransfer.files;

                // Visual feedback
                alert('Foto capturada e selecionada com sucesso!');

                stop();
            }, 'image/jpeg', 0.85);
        }

        // Bind events
        btnStart.onclick = start;
        btnCancel.onclick = stop;
        btnCapture.onclick = capture;
    }

    return {
        init: init
    };
})();
