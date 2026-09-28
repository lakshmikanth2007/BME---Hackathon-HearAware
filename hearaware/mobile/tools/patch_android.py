"""Run once after `flutter create --platforms android .` :  python tools/patch_android.py
Adds the Android permissions, allows ws:// (cleartext) to the LAN server, and raises minSdk to 24."""
import pathlib, re

root = pathlib.Path(__file__).resolve().parent.parent / "android" / "app"
man = root / "src" / "main" / "AndroidManifest.xml"
s = man.read_text()
perms = ["android.permission.INTERNET", "android.permission.CAMERA", "android.permission.RECORD_AUDIO"]
add = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in s)
s = s.replace("<application", add + "    <application", 1) if add else s
if "usesCleartextTraffic" not in s:
    s = s.replace("<application", '<application android:usesCleartextTraffic="true"', 1)
man.write_text(s)
print("manifest patched")

for name in ("build.gradle.kts", "build.gradle"):
    g = root / name
    if g.exists():
        t = g.read_text()
        t2 = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 24" if name.endswith("kts") else "minSdkVersion 24", t)
        g.write_text(t2)
        print(f"{name}: minSdk set to 24" if t != t2 else f"{name}: check minSdk manually (needs >= 24)")
