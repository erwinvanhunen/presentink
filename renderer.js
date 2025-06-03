let undoStack = [];
const MAX_UNDO = 30; // Adjust for memory usage, if you want


const canvas = document.getElementById('draw-canvas');
const ctx = canvas.getContext('2d');
const previewCanvas = document.getElementById('preview-canvas');
const previewCtx = previewCanvas.getContext('2d');


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
    drawingMode = mode;  // Or whatever you want to do
    //ctx.clearRect(0, 0, canvas.width, canvas.height); // Clear everything (including previous drawings)
    drawScreenBorder(); // Draw the border
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

function saveState() {
    if (undoStack.length >= MAX_UNDO) undoStack.shift(); // Limit history
    undoStack.push(canvas.toDataURL());
}


let isPreviewingStraightLine = false;
let isPreviewingArrow = false;
canvas.onmousedown = (e) => {
    if (e.shiftKey && e.metaKey) {
        drawingMode = 'arrow';
    } else {
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
    }
};


canvas.onmousemove = (e) => {
    if (e.shiftKey && e.metaKey) {
        drawingMode = 'arrow';
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
    }
    // In arrow mode, optionally draw preview here (not implemented in this minimal version)
};

canvas.onmouseup = (e) => {
    previewCtx.clearRect(0, 0, previewCanvas.width, previewCanvas.height);

    if (drawingMode === 'freehand' && drawing) {
        ctx.strokeStyle = strokeColor; // Use the selected stroke color';
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
    ctx.strokeStyle = strokeColor // blue line, or whatever color you want
    ctx.lineWidth = 4;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(fromX, fromY);
    ctx.lineTo(toX, toY);
    ctx.stroke();

    // Calculate arrowhead
    const headlen = 20; // length of arrowhead
    const dx = toX - fromX;
    const dy = toY - fromY;
    const angle = Math.atan2(dy, dx);

    // Points for the arrowhead triangle
    const arrowX1 = toX - headlen * Math.cos(angle - Math.PI / 7);
    const arrowY1 = toY - headlen * Math.sin(angle - Math.PI / 7);

    const arrowX2 = toX - headlen * Math.cos(angle + Math.PI / 7);
    const arrowY2 = toY - headlen * Math.sin(angle + Math.PI / 7);

    // Draw the filled red arrowhead
    ctx.beginPath();
    ctx.moveTo(toX, toY);
    ctx.lineTo(arrowX1, arrowY1);
    ctx.lineTo(arrowX2, arrowY2);
    ctx.closePath();
    ctx.fillStyle = strokeColor; // Use the same color as the line
    ctx.fill();

}

function drawScreenBorder() {
    ctx.save();
    ctx.lineWidth = 3; // Adjust thickness as needed
    ctx.strokeStyle = "#cceeeeee"; // Light grey
    ctx.setLineDash([]); // Solid line, no dash
    ctx.strokeRect(3, 3, canvas.width - 6, canvas.height - 6);
    ctx.restore();
}

