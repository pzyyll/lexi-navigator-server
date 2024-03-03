/*
 * File: /Users/zhilicai/Workspace/lexi-navigator-server/app/static/js/translate.js
 * Description: This file contains the JavaScript code for auto resizing text areas and handling window resize events.
 */

const min_height = 150;
const max_height = 800;
const max_length = 6000;
const sm_max_height = 0.15;


let source_text_is_dragging = false;

function autoResize() {
    source_text = document.getElementById('source_text');
    target_text = document.getElementById('target_text');

    mh = window.innerHeight * sm_max_height;

    bottom_space = $('#source_text_count').height(); 

    source_text.style.height = 'auto';
    target_text.style.height = 'auto';

    if (['xs'].includes(getBootstapBreakpoint())) {
        source_text.style.height = Math.min(source_text.scrollHeight + bottom_space, mh) + 'px';
        target_text.style.height = target_text.scrollHeight+ 'px';
        // console.log('xs:', source_text.scrollHeight, target_text.scrollHeight)
    } else {
        source_text_scoll_height = source_text.scrollHeight + bottom_space;
        target_text_scoll_height = target_text.scrollHeight + bottom_space;
        height = Math.max(source_text_scoll_height, target_text_scoll_height);
        height = Math.min(height, max_height);
        height = Math.max(height, min_height);
        source_text.style.height = height + 'px';
        target_text.style.height = height + 'px';
    }
}

function setSourceTextCount(cnt) {
    $('#source_text_count').text(cnt+"/"+max_length)
}


function obSourceTextResize() {
    source_text = document.getElementById('source_text');
    target_text = document.getElementById('target_text');
    source_text_is_dragging = false;

    viewHeight = window.innerHeight;

    start_h = 0;
    start_th = 0;

    const ob_resize = new ResizeObserver(entries => {
        for (let entry of entries) {
            onResize();
        }
    });
    
    function onResize() {
        if (!source_text_is_dragging) {
            return;
        }

        sh = parseInt(window.getComputedStyle(source_text).height, 10);
        th = parseInt(window.getComputedStyle(target_text).height, 10);
        tsh = target_text.scrollHeight;

        console.log('onResize', sh, th, tsh)
        if (tsh > th) {
            h = (start_h + start_th) - sh;
            h = Math.min(h, tsh);
            target_text.style.height = h + 'px';
        }
    }


    let mousedown = function() {
        source_text_is_dragging = true;
        document.addEventListener('mousemove', mousemove);
        document.addEventListener('mouseup', mouseup);
        ob_resize.observe(source_text);

        start_h = parseInt(window.getComputedStyle(source_text).height, 10);
        start_th = parseInt(window.getComputedStyle(target_text).height, 10);

        sh = parseInt(window.getComputedStyle(source_text).height, 10);
        th = parseInt(window.getComputedStyle(target_text).height, 10);
        maxh = parseInt(window.getComputedStyle(source_text).maxHeight, 10);
        console.log('mousedown', sh, th, maxh)
    }
    let mousemove = function() {
        console.log('mousemove')
    }
    let mouseup = function() {
        console.log('mouseup')
        document.removeEventListener('mousemove', mousemove);
        document.removeEventListener('mouseup', mouseup);
        ob_resize.unobserve(source_text);
    }
    source_text.addEventListener('mousedown', mousedown);
}

$(function() {
    source_text = document.getElementById('source_text');
    setSourceTextCount(source_text.value.length);

    //obSourceTextResize();
    autoResize();

    // 监听窗口尺寸变化，适应屏幕变化
    $(window).resize(function() {
        autoResize();
    });

    let timeoutId = null;
    const delay = 500; // 0.5 seconds
    $('#source_text').on('input', function() {
        text = this.value;
        currentLength = text.length;
        if (currentLength > max_length) {
            this.value = text.substring(0, max_length);
        }
        setSourceTextCount(currentLength)
        autoResize();

        clearTimeout(timeoutId);
        if (!text) {
            $('#target_text').val('');
            $('#power_tag').text('');
            autoResize();
            return;
        }
        timeoutId = setTimeout(async function() {
            try {
                const response = await $.ajax({
                    url: '/translate/translate_text',
                    method: 'POST',
                    contentType: 'application/json',
                    data: JSON.stringify({ text: text }),
                });
                $('#target_text').val(response.translate_text);
                autoResize(); // 调整翻译文本框的高度
                $('#power_tag').text(response.api_type); // 显示额外信息
                if (response.parameters) {
                    // 更新URL
                    parameters = new URLSearchParams(response.parameters);
                    const currentUrl = new URL(getBaseUrl());
                    history.pushState(null, '', currentUrl + "?" + parameters.toString());
                } 
            } catch (error) {
                console.error('Error processing text:', error);
                // 处理错误或者在页面上显示错误信息
            }
        }, delay);
    });
});