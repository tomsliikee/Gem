import os
from PIL import Image, ImageDraw

def resize_star_logo(image_path, scale_factor=1.15):
    if not os.path.exists(image_path):
        print(f"Error: {image_path} does not exist.")
        return

    # Load the image
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    pixels = img.load()

    # Find the bounding box of the colorful star (non-white, opaque pixels)
    min_x, min_y = width, height
    max_x, max_y = 0, 0
    found = False

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # Opaque pixels belonging to the star (not white background of the card)
            if a == 255 and (r < 245 or g < 245 or b < 245):
                found = True
                if x < min_x: min_x = x
                if y < min_y: min_y = y
                if x > max_x: max_x = x
                if y > max_y: max_y = y

    if not found:
        print("Error: Could not locate the colorful star logo in the icon.")
        return

    # Crop the star logo
    star_box = (min_x, min_y, max_x + 1, max_y + 1)
    star_img = img.crop(star_box)

    # Fill the original star area with the card's white color
    draw = ImageDraw.Draw(img)
    draw.rectangle(star_box, fill=(255, 255, 255, 255))

    # Resize the star logo by the scale factor
    new_w = int(star_img.width * scale_factor)
    new_h = int(star_img.height * scale_factor)
    star_resized = star_img.resize((new_w, new_h), Image.Resampling.LANCZOS)

    # Paste the resized star back into the center of the card
    paste_x = (width - new_w) // 2
    paste_y = (height - new_h) // 2
    img.paste(star_resized, (paste_x, paste_y), star_resized)

    # Save the updated image
    img.save(image_path, "PNG")
    print(f"Successfully scaled the logo by {int((scale_factor - 1) * 100)}% and saved it to {image_path}")

if __name__ == "__main__":
    # Resize the icon inside Gem assets
    resize_star_logo("/home/toms/projects/Gem/assets/icon.png", scale_factor=1.15)
