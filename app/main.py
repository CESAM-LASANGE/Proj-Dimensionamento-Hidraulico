#!/usr/bin/env python3
"""Inicia o DimEsgoto: abre o projeto Godot desta pasta.

Uso: python3 main.py [--screenshot arquivo.png]
"""
import glob
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def find_godot():
    for var in ("GODOT", "GODOT_BIN"):
        p = os.environ.get(var)
        if p and os.path.isfile(p):
            return p
    for name in ("godot4", "godot", "Godot"):
        p = shutil.which(name)
        if p:
            return p
    config_homes = [
        os.environ.get("XDG_CONFIG_HOME", ""),
        os.path.expanduser("~/.var/app/ai.storyteller.craft-anything/config"),
        os.path.expanduser("~/.config"),
        os.path.expanduser("~/Library/Application Support"),
        os.environ.get("APPDATA", ""),
    ]
    for home in config_homes:
        if not home:
            continue
        folder = os.path.join(home, "craft-anything", "engines", "godot")
        for f in sorted(glob.glob(os.path.join(folder, "**", "Godot_v4*"), recursive=True), reverse=True):
            if os.path.isfile(f) and os.access(f, os.X_OK) and not f.endswith((".zip", ".pck")):
                return f
    return None


def main():
    args = sys.argv[1:]
    out = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--screenshot" and i + 1 < len(args):
            out += ["--screenshot", os.path.abspath(args[i + 1])]
            i += 2
            continue
        if a.startswith("--screenshot="):
            out.append("--screenshot=" + os.path.abspath(a.split("=", 1)[1]))
        else:
            out.append(a)
        i += 1
    godot = find_godot()
    if not godot:
        sys.stderr.write("Godot 4 não encontrado. Instale o Godot 4.4 ou defina a variável GODOT.\n")
        return 1
    return subprocess.call([godot, "--path", HERE, "--"] + out)


if __name__ == "__main__":
    sys.exit(main())
