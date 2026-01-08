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
        // clsCampos generates label with for="id"
        var label = document.querySelector('label[for="' + photoInput.id + '"]');

        // Create "Open Camera" button
        var btnStart = document.createElement('input');
        btnStart.type = 'button';
        btnStart.value = '📷 Abrir Câmera';
        btnStart.className = 'btn_small';
        btnStart.id = 'btn-webcam-' + inputId;
        // Adjust margins to align with the "Escolha um arquivo" button/label
        // The label likely has some display property, we want to sit next to it.
        btnStart.style.margin = '0 0 0 10px';
        btnStart.style.verticalAlign = 'middle';

        // Insert button after the label.
        // The label is often followed by a text node (space) and BR or description text.
        // We insert immediately after the label to try to keep it on the same line.
        if (label && label.nextSibling) {
            label.parentNode.insertBefore(btnStart, label.nextSibling);
        } else if (label) {
            label.parentNode.appendChild(btnStart);
        } else {
            // Fallback
            photoInput.parentNode.appendChild(btnStart);
        }

        // Container for video/canvas
        var container = document.createElement('div');
        container.id = 'webcam-container-' + inputId;
        container.style.display = 'none';
        container.style.marginTop = '10px';
        container.style.textAlign = 'center';
        container.style.backgroundColor = '#f5f9fd';
        container.style.border = '1px solid #cddce6';
        container.style.padding = '10px';
        container.style.borderRadius = '3px';

        var video = document.createElement('video');
        video.setAttribute('autoplay', '');
        video.setAttribute('playsinline', '');
        video.style.maxWidth = '100%';
        video.style.maxHeight = '400px';
        video.style.height = 'auto';

        var canvas = document.createElement('canvas');
        canvas.style.maxWidth = '100%';
        canvas.style.height = 'auto';
        canvas.style.display = 'none';

        var controls = document.createElement('div');
        controls.style.marginTop = '10px';

        function createBtn(value, cls, clickHandler) {
            var btn = document.createElement('input');
            btn.type = 'button';
            btn.value = value;
            btn.className = cls;
            btn.style.margin = '0 5px';
            btn.onclick = clickHandler;
            return btn;
        }

        // btn-green for primary action, btn_small for others
        var btnCapture = createBtn('Capturar', 'btn-green', capture);
        var btnRecapture = createBtn('Tirar Outra', 'btn_small', start);
        var btnCancel = createBtn('Fechar', 'btn_small', stop);

        btnRecapture.style.display = 'none';

        controls.appendChild(btnCapture);
        controls.appendChild(btnRecapture);
        controls.appendChild(btnCancel);

        container.appendChild(video);
        container.appendChild(canvas);
        container.appendChild(controls);

        // Append container to the parent cell (at the bottom, after description)
        photoInput.parentNode.appendChild(container);

        var stream = null;

        function start() {
            container.style.display = 'block';
            video.style.display = 'inline-block';
            canvas.style.display = 'none';
            btnCapture.style.display = 'inline-block';
            btnRecapture.style.display = 'none';
            btnStart.disabled = true;

            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                navigator.mediaDevices.getUserMedia({ video: true })
                    .then(function(s) {
                        stream = s;
                        video.srcObject = stream;
                        video.play();
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
            container.style.display = 'none';
            btnStart.disabled = false;
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

                // Create file
                var file = new File([blob], "foto_camera.jpg", { type: "image/jpeg" });

                // Assign to input
                try {
                    var dataTransfer = new DataTransfer();
                    dataTransfer.items.add(file);
                    photoInput.files = dataTransfer.files;
                } catch(e) {
                    console.error("DataTransfer error: ", e);
                }

                // Dispatch change event so other scripts can react
                photoInput.dispatchEvent(new Event('change'));

                // Update label manually just in case
                if (label) {
                    var span = label.querySelector('span');
                    if (span) {
                        span.innerText = file.name;
                        // span.style.color = '#47728f';
                    }
                }

                // Show preview (keep container visible)
                video.style.display = 'none';
                canvas.style.display = 'inline-block';
                btnCapture.style.display = 'none';
                btnRecapture.style.display = 'inline-block';

                // Stop stream to save resources
                if (stream) {
                     stream.getTracks().forEach(function(track) {
                        track.stop();
                    });
                    stream = null;
                }

            }, 'image/jpeg', 0.85);
        }

        btnStart.onclick = start;
    }

    return {
        init: init
    };
})();
