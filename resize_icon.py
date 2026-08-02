import sys
from PIL import Image

def scale_icon(image_path, scale_factor):
    try:
        # Open the image
        img = Image.open(image_path)
        img = img.convert("RGBA")
        
        # Original size
        width, height = img.size
        
        # Calculate new size
        new_width = int(width * scale_factor)
        new_height = int(height * scale_factor)
        
        # Resize image using high-quality downsampling (LANCZOS)
        resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Create a new transparent background with original size
        new_bg = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        
        # Calculate position to center the resized image
        # If scale_factor > 1, the new image is bigger. We center it and paste.
        offset_x = (width - new_width) // 2
        offset_y = (height - new_height) // 2
        
        # Paste the resized image into the new background
        # since offset_x and offset_y can be negative, standard paste handles it fine if we just want to crop
        # Wait, if we crop, Image.paste with negative coordinates might behave differently.
        # So we crop the resized_img instead.
        if scale_factor > 1.0:
            left = -offset_x
            top = -offset_y
            right = left + width
            bottom = top + height
            cropped = resized_img.crop((left, top, right, bottom))
            new_bg.paste(cropped, (0, 0))
        else:
            new_bg.paste(resized_img, (offset_x, offset_y))
        
        # Save back
        new_bg.save(image_path)
        print(f"✅ Icon successfully scaled by {scale_factor * 100}%!")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python resize_icon.py <image_path>")
        sys.exit(1)
        
    scale_icon(sys.argv[1], 1.05)
