var WebcamCapture = (function() {
    function init(inputId) {
        console.log('WebcamCapture: Iniciando para o campo ' + inputId);
        
        // Localiza o campo de input de arquivo
        var photoInput = document.getElementById(inputId) || document.getElementsByName(inputId)[0];
        if (!photoInput) {
            console.error('WebcamCapture: Campo de entrada não encontrado.');
            return;
        }

        if (document.getElementById('btn-webcam-' + inputId)) return;

        // Identifica o botão verde original para posicionamento
        var labelButton = photoInput.nextElementSibling;
        
        // --- CRIAÇÃO DO BOTÃO "ABRIR CÂMERA" ---
        var btnStart = document.createElement('button'); 
        btnStart.innerText = 'Abrir Câmera';
        btnStart.type = 'button';
        btnStart.className = 'btn-webcam-custom'; // Aplica sua classe do custom.css
        btnStart.id = 'btn-webcam-' + inputId;
        
        // Estilos de segurança para garantir o padrão visual
        btnStart.style.cssText = "background-color: #0ac336 !important; color: #FFF !important; border: 0; border-radius: 3px; padding: 8px 15px; margin-left: 5px; cursor: pointer; vertical-align: top; font-family: 'Open Sans', sans-serif; font-size: 14px; font-weight: bold;";

        // Posicionamento: Mantém o padrão ao lado do "Escolha um arquivo"
        if (labelButton && labelButton.tagName.toLowerCase() === 'label') {
            labelButton.parentNode.insertBefore(btnStart, labelButton.nextSibling);
        } else {
            photoInput.parentNode.insertBefore(btnStart, photoInput.nextSibling);
        }

        // --- ESTRUTURA DE UI (VÍDEO E CONTROLES) ---
        var uiWrapper = document.createElement('div');
        uiWrapper.id = 'webcam-ui-' + inputId;
        uiWrapper.style.cssText = "display: none; margin-top: 15px; clear: both;";

        uiWrapper.innerHTML = `
            <div style="background: #f5f9fd; padding: 15px; border: 1px solid #cddce6; border-radius: 3px; display: inline-block;">
                <select id="select-cam-${inputId}" class="form-control" style="display:none; margin-bottom: 10px; width: 240px;"></select>
                <video id="vid-${inputId}" width="240" height="320" autoplay style="border: 1px solid #47728f; background: #000; border-radius: 3px; display: block; object-fit: cover;"></video>
                <canvas id="canv-${inputId}" width="240" height="320" style="display:none;"></canvas>
                <button type="button" id="btn-snap-${inputId}" class="btn-webcam-custom" style="margin-top: 10px; width: 100%; background-color: #0ac336; color: #FFF; border:0; padding: 10px; border-radius: 3px; cursor: pointer; font-weight: bold;">Tirar Foto 3x4</button>
            </div>
        `;

        // --- DIV DE PREVIEW (MANTIDA FORA DO UIWRAPPER) ---
        var previewDiv = document.createElement('div');
        previewDiv.id = 'prev-' + inputId;
        previewDiv.style.cssText = "margin-top: 10px; clear: both;";

        btnStart.parentNode.appendChild(uiWrapper);
        btnStart.parentNode.appendChild(previewDiv);

        var stream = null;

        // --- LÓGICA DE ABERTURA/FECHAMENTO ---
        btnStart.onclick = function(e) {
            e.preventDefault();
            if (stream) {
                stream.getTracks().forEach(t => t.stop());
                stream = null;
                uiWrapper.style.display = 'none';
                btnStart.innerText = 'Abrir Câmera';
                btnStart.style.backgroundColor = '#0ac336';
            } else {
                navigator.mediaDevices.getUserMedia({ video: true })
                .then(function(s) {
                    stream = s;
                    var video = document.getElementById('vid-' + inputId);
                    video.srcObject = s;
                    uiWrapper.style.display = 'block';
                    btnStart.innerText = 'Fechar Câmera';
                    btnStart.style.backgroundColor = '#aa2e28';
                })
                .catch(function(err) {
                    alert("Erro ao acessar câmera: " + err.name);
                });
            }
        };

        // --- LÓGICA DE CAPTURA COM CORTE 3x4 ---
        document.getElementById('btn-snap-' + inputId).onclick = function() {
            var video = document.getElementById('vid-' + inputId);
            var canvas = document.getElementById('canv-' + inputId);
            var ctx = canvas.getContext('2d');

            // Proporção 3x4 (Retrato)
            var targetW = 240;
            var targetH = 320;
            var videoW = video.videoWidth;
            var videoH = video.videoHeight;

            // Calcula o corte centralizado
            var sourceW = videoH * (targetW / targetH);
            var sourceX = (videoW - sourceW) / 2;

            ctx.clearRect(0, 0, targetW, targetH);
            ctx.drawImage(video, sourceX, 0, sourceW, videoH, 0, 0, targetW, targetH);
            
            canvas.toBlob(function(blob) {
                var file = new File([blob], "foto_aluno.jpg", { type: "image/jpeg", lastModified: new Date().getTime() });
                var dt = new DataTransfer();
                dt.items.add(file);
                photoInput.files = dt.files;
                
                // Exibe a preview no div externo para que não suma ao fechar a câmera
                previewDiv.innerHTML = 
                    '<strong>Preview capturada:</strong><br><img src="'+URL.createObjectURL(blob)+'" width="120" height="160" style="border: 2px solid #28a745; margin-top:5px; border-radius: 3px;">';
                
                btnStart.click(); // Fecha os controles da câmera
                photoInput.dispatchEvent(new Event('change', { bubbles: true }));
            }, 'image/jpeg', 0.9);
        };
    }

    return { init: init };
})();
