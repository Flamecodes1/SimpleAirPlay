import urllib.request
import json
import zipfile
import os
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

url = "https://api.github.com/repos/FDH2/UxPlay-Windows/releases/latest"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})

print(f"Fetching latest release from {url}...")
try:
    with urllib.request.urlopen(req, context=ctx) as response:
        data = json.loads(response.read().decode())
        
        download_url = None
        for asset in data.get('assets', []):
            if asset['name'].endswith('.zip'):
                download_url = asset['browser_download_url']
                break
        
        if not download_url:
            print("Could not find a .zip asset in the latest release.")
            exit(1)
            
        print(f"Found ZIP URL: {download_url}")
        
        zip_path = "uxplay_downloaded.zip"
        print(f"Downloading to {zip_path}...")
        
        req_zip = urllib.request.Request(download_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req_zip, context=ctx) as r, open(zip_path, 'wb') as f:
            f.write(r.read())
            
        print("Download complete. Extracting...")
        
        target_dirs = ["bin/Debug/net8.0-windows", "bin/Release/net8.0-windows"]
        for target_dir in target_dirs:
            os.makedirs(target_dir, exist_ok=True)
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(target_dir)
            print(f"Extracted to {target_dir}")
        
        print("Done!")
except Exception as e:
    print(f"Error: {e}")
