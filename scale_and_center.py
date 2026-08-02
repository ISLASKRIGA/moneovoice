import sys
from PIL import Image

def scale_and_center(image_path, scale_factor=1.05):
    try:
        img = Image.open(image_path).convert("RGBA")
        
        # Get bounding box of the non-transparent pixels
        bbox = img.getbbox()
        if not bbox:
            print("Image is entirely transparent.")
            return

        # Crop the logo itself
        cropped_logo = img.crop(bbox)
        
        # Scale the cropped logo by 5%
        new_width = int(cropped_logo.size[0] * scale_factor)
        new_height = int(cropped_logo.size[1] * scale_factor)
        
        # Scale using Lancashire resampling
        scaled_logo = cropped_logo.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Create a new transparent image with the original canvas size (usually 1024x1024)
        new_bg = Image.new("RGBA", img.size, (0, 0, 0, 0))
        
        # Calculate new X and Y to perfectly center the scaled logo
        x = (img.size[0] - scaled_logo.size[0]) // 2
        y = (img.size[1] - scaled_logo.size[1]) // 2
        
        # Paste and save
        new_bg.paste(scaled_logo, (x, y))
        new_bg.save(image_path)
        print(f"Icon increased by {scale_factor * 100}% and perfectly centered!")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scale_and_center.py <image_path>")
        sys.exit(1)
        
    scale_and_center(sys.argv[1], 1.05)
