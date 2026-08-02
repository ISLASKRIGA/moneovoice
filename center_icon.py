import sys
from PIL import Image

def center_icon(image_path):
    try:
        img = Image.open(image_path).convert("RGBA")
        
        # Get the bounding box of the non-transparent pixels
        bbox = img.getbbox()
        if not bbox:
            print("Image is entirely transparent.")
            return

        # crop the logo itself
        cropped_logo = img.crop(bbox)
        
        # Create a new transparent image with the original canvas size
        new_bg = Image.new("RGBA", img.size, (0, 0, 0, 0))
        
        # Calculate new X and Y to perfectly center the logo mathematically
        x = (img.size[0] - cropped_logo.size[0]) // 2
        y = (img.size[1] - cropped_logo.size[1]) // 2
        
        new_bg.paste(cropped_logo, (x, y))
        new_bg.save(image_path)
        print("Icon centered successfully!")
        
    except Exception as e:
        print(f"Error centering icon: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python center_icon.py <image_path>")
        sys.exit(1)
        
    center_icon(sys.argv[1])
