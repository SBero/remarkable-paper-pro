# Wallpaper Changer

Easily setup a script that changes the wallpaper you have on the device every 4 hours. 

You can change this interval at the top of the script.

I highly suggest using an SFTP software to make file transfers easier.

Note: Images *must* be .PNG files.

### :heart: Installation
1. SSH into your RMPP and setup the wallpaper folder:
```
mkdir -p /home/root/wallpapers
```
2. Copy your wallpapers into the above folder either with scp or an SFTP software.
   
3. Copy the `wallpaper-changer.sh` file to your RMPP home directory (/home/root) via ssh. Here's how you can do it using scp:
```
scp wallpaper-changer.sh root@[your-remarkable-ip]:/home/root/
```
Otherwise use an SFTP software.

4. SSH into your RMPP and make the script executable:
```
chmod +x /home/root/wallpaper-changer.sh
```

5. Install the service:
```
.wallpaper-changer.sh install
```

---

### :mag: Check the service status:
```
systemctl status wallpaper-changer.timer
```
---
### :raised_hands: Test the service:
```
./wallpaper-changer.sh test
```
---

### :running: Run the wallpaper changer once:
```
./wallpaper-changer.sh run
```
---
### :broken_heart: Uninstall the service:
```
./wallpaper-changer.sh uninstall
```