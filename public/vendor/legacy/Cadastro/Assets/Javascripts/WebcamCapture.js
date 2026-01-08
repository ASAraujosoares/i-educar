var WebcamCapture = (function() {

    function init(inputId) {
        var photoInput = document.getElementById(inputId);
        if (!photoInput) {
            var inputs = document.getElementsByName(inputId);
            if (inputs.length > 0) {
                photoInput = inputs[0];
            } else {
                 console.log('WebcamCapture: Input ' + inputId + ' not found.');
                 return;
            }
        }

        if (document.getElementById('btn-webcam-' + inputId)) {
            return;
        }

        // Find the label associated with the input
        var label = document.querySelector('label[for="' + photoInput.id + '"]');

        // Create "Open Camera" button
        var btnStart = document.createElement('a');
        btnStart.innerText = '📷 Abrir Câmera';
        btnStart.className = 'btn-green';
        btnStart.id = 'btn-webcam-' + inputId;

        // Styling to match the "Escolha um arquivo" button
        btnStart.style.cursor = 'pointer';
        btnStart.style.display = 'inline-block';
        btnStart.style.fontWeight = 'bold';
        btnStart.style.padding = '8px';
        btnStart.style.borderRadius = '3px';
        btnStart.style.marginLeft = '5px';
        btnStart.style.fontSize = '14px';
        btnStart.style.lineHeight = 'normal';
        btnStart.style.textDecoration = 'none';
        btnStart.style.color = '#FFF';
        btnStart.style.verticalAlign = 'top'; // Align with the label/input box

        // Insert button after the label
        if (label && label.nextSibling) {
            label.parentNode.insertBefore(btnStart, label.nextSibling);
        } else if (label) {
            label.parentNode.appendChild(btnStart);
        } else {
            photoInput.parentNode.appendChild(btnStart);
        }

        // Container for video/canvas
        var container = document.createElement('div');
        container.id = 'webcam-container-' + inputId;
        container.style.display = 'none';
        container.style.marginTop = '10px';
        container.style.textAlign = 'left';

        var previewLabel = document.createElement('div');
        previewLabel.innerText = 'Preview da captura:';
        previewLabel.style.color = '#47728f';
        previewLabel.style.fontWeight = 'bold';
        previewLabel.style.marginBottom = '5px';
        previewLabel.style.fontSize = '14px';

        var video = document.createElement('video');
        video.setAttribute('autoplay', '');
        video.setAttribute('playsinline', '');
        video.style.width = '240px';
        video.style.height = '180px';
        video.style.objectFit = 'cover';
        video.style.border = '2px solid #0ac336';

        var canvas = document.createElement('canvas');
        canvas.style.width = '240px';
        canvas.style.height = '180px';
        canvas.style.objectFit = 'cover';
        canvas.style.display = 'none';
        canvas.style.border = '2px solid #0ac336';

        container.appendChild(previewLabel);
        container.appendChild(video);
        container.appendChild(canvas);

        var btnCapture = document.createElement('button');
        btnCapture.innerText = 'Capturar Foto';
        btnCapture.className = 'btn-green';
        btnCapture.style.display = 'block';
        btnCapture.style.marginTop = '5px';
        btnCapture.style.padding = '5px 10px';
        btnCapture.style.fontSize = '12px';
        btnCapture.style.width = '240px';
        btnCapture.type = 'button'; // Prevent form submission

        container.appendChild(btnCapture);

        photoInput.parentNode.appendChild(container);

        var stream = null;
        var isCameraActive = false;

        function start() {
            if (isCameraActive) return;

            container.style.display = 'block';
            video.style.display = 'block';
            canvas.style.display = 'none';
            btnCapture.style.display = 'block';

            btnStart.innerText = '📷 Fechar Câmera';
            btnStart.style.backgroundColor = '#aa2e28'; // Red for cancel

            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                navigator.mediaDevices.getUserMedia({ video: true })
                    .then(function(s) {
                        stream = s;
                        video.srcObject = stream;
                        video.play();
                        isCameraActive = true;
                    })
                    .catch(function(err) {
                        console.error("Webcam error: " + err);
                        alert('Não foi possível acessar a câmera: ' + err.message);
                        stop();
                    });
            } else {
                alert('Seu navegador não suporta acesso à câmera.');
                stop();
            }
        }

        function stop() {
            if (stream) {
                stream.getTracks().forEach(function(track) {
                    track.stop();
                });
                stream = null;
            }
            if (canvas.style.display === 'none') {
                 container.style.display = 'none';
            }

            isCameraActive = false;
            btnStart.innerText = '📷 Tirar outra foto';
            btnStart.style.backgroundColor = '#0ac336';
        }

        function toggle() {
            if (isCameraActive) {
                stop();
            } else {
                start();
            }
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
                    alert('A imagem é muito grande (>2MB).');
                    return;
                }

                var file = new File([blob], "foto_camera.jpg", { type: "image/jpeg" });

                try {
                    var dataTransfer = new DataTransfer();
                    dataTransfer.items.add(file);
                    photoInput.files = dataTransfer.files;
                } catch(e) {
                    console.error("DataTransfer error: ", e);
                }

                photoInput.dispatchEvent(new Event('change'));

                if (label) {
                    var span = label.querySelector('span');
                    if (span) {
                        span.innerText = file.name;
                    }
                }

                video.style.display = 'none';
                canvas.style.display = 'block';
                btnCapture.style.display = 'none';

                if (stream) {
                     stream.getTracks().forEach(function(track) {
                        track.stop();
                    });
                    stream = null;
                }
                isCameraActive = false;

                btnStart.innerText = '📷 Tirar outra foto';
                btnStart.style.backgroundColor = '#0ac336';

            }, 'image/jpeg', 0.85);
        }

        btnStart.onclick = toggle;
        btnCapture.onclick = capture;
    }

    return {
        init: init
    };
})();
