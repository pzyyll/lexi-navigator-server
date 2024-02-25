# -*- coding:utf-8 -*-
# @Date: "2024-02-22"
# @Description: api utils

import random


def simple_random_text_segments(text, length=60, n=3):
    # Calculate the maximum start index for a segment
    max_start_index = len(text) - length
    
    # Check if the text is too short to get n segments of the specified length
    if max_start_index < 0 or n * length > len(text):
        return text
    
    segments = ""
    for _ in range(n):
        # Ensure unique segments by checking overlaps
        start_index = random.randint(0, max_start_index)
        
        # Extract the segment
        segment = text[start_index:start_index + length]
        
        # Add the extracted segment 
        segments += segment
    return segments
