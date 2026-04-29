from PIL import Image

def remove_white_bg(input_path, output_path, tolerance=30):
    img = Image.open(input_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        # Check if the pixel is close to white
        # White is (255, 255, 255)
        if item[0] > 255 - tolerance and item[1] > 255 - tolerance and item[2] > 255 - tolerance:
            # Calculate a smooth alpha based on distance to pure white
            dist = ( (255-item[0]) + (255-item[1]) + (255-item[2]) ) / 3
            alpha = int((dist / tolerance) * 255)
            # Make it fully transparent if it's really white
            if dist < 5:
                new_data.append((255, 255, 255, 0))
            else:
                # Keep color, but reduce alpha
                new_data.append((item[0], item[1], item[2], alpha))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(output_path, "PNG")

remove_white_bg("assets/images/logo.png", "assets/images/logo_transparent.png", tolerance=40)
print("Done")
