function getBootstapBreakpoint() {
    return window.getComputedStyle(document.body, '::before').getPropertyValue('content').replace(/\"/g, '');
}
