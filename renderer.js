let undoStack = [];
const MAX_UNDO = 30; // Adjust for memory usage, if you want


const canvas = document.getElementById('draw-canvas');
const ctx = canvas.getContext('2d');
const previewCanvas = document.getElementById('preview-canvas');
const previewCtx = previewCanvas.getContext('2d');

canvas.style.cursor = "crosshair";


let drawingMode = 'freehand'; // Default mode
let startX = 0, startY = 0;
let prevX = 0, prevY = 0;
let lineStartX = 0, lineStartY = 0;
let strokeColor = '#ff0000'
function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    previewCanvas.width = window.innerWidth;
    previewCanvas.height = window.innerHeight;


}
resize();
window.addEventListener('resize', resize);
window.addEventListener('DOMContentLoaded', () => {
    const intro = document.getElementById('app-intro');
    intro.style.opacity = '1';

    setTimeout(() => {
        intro.style.opacity = '0';
    }, 2000); // Show for 2 seconds

    setTimeout(() => {
        intro.style.display = 'none';
    }, 3000); // Fully hide after fade out

});
let drawing = false;
let last = null;

window.electronAPI.onSetMode((event, mode) => {
    drawingMode = mode;
    drawScreenBorder();
    saveState();
});

window.electronAPI.onClearDrawing(() => {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawScreenBorder(); // Draw the border
});

window.electronAPI.onSetColor((event, color) => {
    strokeColor = color; // Update the stroke color
    drawScreenBorder(); // Draw the border
});

window.electronAPI.onShiftToggle(() => {
    shiftDown = !shiftDown; // Toggle shift state
});

window.electronAPI.onUndo(() => {
    undo();
});

window.electronAPI.onClearUndo(() => {
    undoStack = []; // Clear the undo stack
});

function saveState() {
    if (undoStack.length >= MAX_UNDO) undoStack.shift(); // Limit history
    undoStack.push(canvas.toDataURL());
}


let isPreviewingStraightLine = false;
let isPreviewingArrow = false;
let isPreviewingBox = false;
let isPreviewingCircle = false;

canvas.onmousedown = (e) => {
    isPreviewingArrow = false;
    isPreviewingBox = false;
    isPreviewingStraightLine = false;
    isPreviewingCircle = false;
    if (e.shiftKey && e.metaKey) {
        drawingMode = 'arrow';
    }
    else if (e.metaKey) {
        drawingMode = 'box';
    } else if (e.altKey) {
        drawingMode = 'circle';
    }
    else {
        drawingMode = 'freehand';
    }
    if (drawingMode === 'freehand') {
        drawing = true;
        prevX = e.offsetX;
        prevY = e.offsetY;
        lineStartX = e.offsetX;
        lineStartY = e.offsetY;
        isPreviewingStraightLine = e.shiftKey; // Are we drawing a straight line?
    } else if (drawingMode === 'arrow') {
        drawing = true;
        startX = e.offsetX;
        startY = e.offsetY;
        isPreviewingArrow = true;
    } else if (drawingMode === 'box') {
        drawing = true;
        startX = e.offsetX;
        startY = e.offsetY;
        isPreviewingBox = true;
    } else if (drawingMode === 'circle') {
        drawing = true;
        startX = e.offsetX;
        startY = e.offsetY;
        isPreviewingCircle = true;
    }
};


canvas.onmousemove = (e) => {
    if (e.shiftKey && e.metaKey) {
        drawingMode = 'arrow';
    }
    else if (e.metaKey) {
        drawingMode = 'box';
    } else if (e.altKey) {
        drawingMode = 'circle';
    } else {
        drawingMode = 'freehand';
    }
    if (drawingMode === 'freehand' && drawing) {

        ctx.strokeStyle = strokeColor;
        ctx.lineWidth = 3;
        ctx.lineCap = 'round';
        previewCtx.strokeStyle = strokeColor;
        previewCtx.lineWidth = 3;
        previewCtx.lineCap = 'round';
        // If shift is held either since mousedown or now
        if (isPreviewingStraightLine || e.shiftKey) {
            // Optional: live preview by clearing and redrawing background/border
            previewCtx.clearRect(0, 0, canvas.width, canvas.height);
            previewCtx.beginPath();
            previewCtx.moveTo(lineStartX, lineStartY);
            previewCtx.lineTo(e.offsetX, e.offsetY);
            previewCtx.stroke();
        } else {
            // Normal freehand
            ctx.beginPath();
            ctx.moveTo(prevX, prevY);
            ctx.lineTo(e.offsetX, e.offsetY);
            ctx.stroke();
            prevX = e.offsetX;
            prevY = e.offsetY;
            previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);

        }
    } else if (drawingMode === 'arrow' && drawing) {
        previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
        if (isPreviewingArrow) {
            // Draw a preview of the arrow
            drawArrow(previewCtx, startX, startY, e.offsetX, e.offsetY);
        }
    } else if (drawingMode === 'box' && drawing) {
        previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
        if (isPreviewingBox) {
            previewCtx.strokeStyle = strokeColor; // or any box color you want
            previewCtx.lineWidth = 3;
            previewCtx.strokeRect(
                startX,
                startY,
                e.offsetX - startX,
                e.offsetY - startY
            );
        }
    } else if (drawingMode === 'circle' && drawing) {
        previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
        if (isPreviewingCircle) {
            const x = Math.min(startX, e.offsetX);
            const y = Math.min(startY, e.offsetY);
            const w = Math.abs(e.offsetX - startX);
            const h = Math.abs(e.offsetY - startY);
            previewCtx.lineWidth = 3;
            previewCtx.strokeStyle = strokeColor;
            previewCtx.beginPath();
            previewCtx.ellipse(
                x + w / 2,        // centerX
                y + h / 2,        // centerY
                w / 2,            // radiusX
                h / 2,            // radiusY
                0,                // rotation
                0,
                Math.PI * 2
            );
            previewCtx.stroke();
        }
    }
};

canvas.oncontextmenu = (e) => {
    e.preventDefault();
};

canvas.onmouseup = (e) => {
    if (e.button === 2) {
        // Right-click: do nothing
        drawingMode = 'none';
        drawing = false;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);
        window.electronAPI.exitDrawing();
        return;
    }
    previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);

    if (drawingMode === 'freehand' && drawing) {
        ctx.strokeStyle = strokeColor;
        ctx.lineWidth = 3;
        ctx.lineCap = 'round';
        if (isPreviewingStraightLine || e.shiftKey) {
            // Commit the straight line
            ctx.beginPath();
            ctx.moveTo(lineStartX, lineStartY);
            ctx.lineTo(e.offsetX, e.offsetY);
            ctx.stroke();
        }
        drawing = false;
        isPreviewingStraightLine = false;
    } else if (drawingMode === 'arrow' && drawing) {
        drawing = false;
        drawArrow(ctx, startX, startY, e.offsetX, e.offsetY);
    } else if (drawingMode === 'box' && drawing) {
        drawing = false;
        ctx.strokeStyle = strokeColor;
        ctx.lineWidth = 3;
        ctx.lineCap = 'round';
        ctx.strokeRect(
            startX,
            startY,
            e.offsetX - startX,
            e.offsetY - startY
        );
    } else if (drawingMode === 'circle' && drawing) {
        drawing = false;
        ctx.strokeStyle = strokeColor;
        ctx.lineWidth = 3;
        const x = Math.min(startX, e.offsetX);
        const y = Math.min(startY, e.offsetY);
        const w = Math.abs(e.offsetX - startX);
        const h = Math.abs(e.offsetY - startY);

        ctx.beginPath();
        ctx.ellipse(
            x + w / 2,        // centerX
            y + h / 2,        // centerY
            w / 2,            // radiusX
            h / 2,            // radiusY
            0,                // rotation
            0,
            Math.PI * 2
        );
        ctx.stroke();

    }
    saveState(); // Save the state after drawing
};

function undo() {
    if (undoStack.length > 1) {
        undoStack.pop(); // Remove current state
        const imgData = undoStack[undoStack.length - 1];
        let img = new window.Image();
        img.onload = function () {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            // Redraw border if needed:
            if (drawingMode === 'freehand' || drawingMode === 'arrow') drawScreenBorder && drawScreenBorder();
        };
        img.src = imgData;
    } else if (undoStack.length === 1) {
        // Clear canvas if only the initial state remains
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        if (drawingMode === 'freehand' || drawingMode === 'arrow') drawScreenBorder && drawScreenBorder();
    }
}

let shiftDown = false;



canvas.onmouseleave = () => { drawing = false; };

// Prevent right-click context menu
window.addEventListener('contextmenu', e => e.preventDefault());

function drawArrow(ctx, fromX, fromY, toX, toY) {
    const headlen = 20; // Arrowhead length
    const dx = toX - fromX;
    const dy = toY - fromY;
    const angle = Math.atan2(dy, dx);

    // Calculate endpoint of the shaft (before the arrowhead starts)
    const shaftX = toX - (headlen - 2) * Math.cos(angle);
    const shaftY = toY - (headlen - 2) * Math.sin(angle);

    // Draw shaft
    ctx.strokeStyle = strokeColor; // Use the selected stroke color
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(fromX, fromY);
    ctx.lineTo(shaftX, shaftY);
    ctx.stroke();

    // Draw filled arrowhead 
    const arrowX1 = toX - headlen * Math.cos(angle - Math.PI / 7);
    const arrowY1 = toY - headlen * Math.sin(angle - Math.PI / 7);

    const arrowX2 = toX - headlen * Math.cos(angle + Math.PI / 7);
    const arrowY2 = toY - headlen * Math.sin(angle + Math.PI / 7);

    ctx.beginPath();
    ctx.moveTo(toX, toY);
    ctx.lineTo(arrowX1, arrowY1);
    ctx.lineTo(arrowX2, arrowY2);
    ctx.closePath();
    ctx.fillStyle = strokeColor;
    ctx.fill();
}

function drawScreenBorder() {

    // ctx.save();
    // ctx.lineWidth = 3;
    // ctx.strokeStyle = "#cceeeeee";
    // ctx.setLineDash([]); // Solid line, no dash
    // ctx.strokeRect(3, 3, canvas.width - 6, canvas.height - 6);
    // ctx.restore();

}