#!/usr/bin/env python3
"""Baut standard/rechner-standard.css und standard/rechner-brand.js in alle Rechner ein.
Jeder Rechner enthält die Marker <!--RB-STANDARD--> ... <!--/RB-STANDARD--> im <head>.
Aufruf: python3 tools/build_standard.py   (im Repository-Ordner)"""
import pathlib, re, sys
root = pathlib.Path(__file__).resolve().parent.parent
css = (root / 'standard/rechner-standard.css').read_text(encoding='utf-8')
js = (root / 'standard/rechner-brand.js').read_text(encoding='utf-8')
block = '<!--RB-STANDARD-->\n<style id="rb-standard">\n' + css + '</style>\n<script id="rb-brand">\n' + js + '</script>\n<!--/RB-STANDARD-->'
pat = re.compile(r'<!--RB-STANDARD-->.*?<!--/RB-STANDARD-->', re.S)
n = 0
for f in sorted(root.glob('*.html')):
    s = f.read_text(encoding='utf-8')
    if '<!--RB-STANDARD-->' not in s:
        continue
    new = pat.sub(lambda m: block, s)
    if new != s:
        f.write_text(new, encoding='utf-8'); n += 1
    print('ok', f.name)
print(n, 'Datei(en) aktualisiert')
