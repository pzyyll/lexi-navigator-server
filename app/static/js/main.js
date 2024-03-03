function getBootstapBreakpoint() {
    return window.getComputedStyle(document.body, '::before').getPropertyValue('content').replace(/\"/g, '');
}

function getBaseUrl() {
    const url = window.location.href; // 获取当前页面的完整URL
    const index = url.indexOf('?'); // 找到"?"的位置
    if (index !== -1) {
      return url.substring(0, index); // 如果存在"?"，则返回"?"之前的部分
    }
    return url; // 如果不存在"?"，则直接返回完整URL
  }
  