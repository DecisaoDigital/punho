#!/usr/bin/env python3
"""Lê o ecrã do telemóvel como texto, para testes manuais guiados por adb.

Existe porque um screenshot custa dezenas de milhares de tokens a ler e uma
árvore de acessibilidade custa umas centenas. `uiautomator dump` só enxerga a
semântica do Flutter com o Select to Speak ligado (ver memória do projecto).

  ui.py                  → lista o que está no ecrã, com coordenadas
  ui.py toca "Entrar"    → toca no centro do primeiro nó que casa
  ui.py escreve "texto"  → escreve no campo com foco
"""
import re, subprocess, sys, time

def dump():
    for _ in range(3):
        subprocess.run(['adb','shell','uiautomator','dump','/sdcard/ui.xml'],
                       capture_output=True, timeout=60)
        x = subprocess.run(['adb','shell','cat','/sdcard/ui.xml'],
                           capture_output=True, timeout=60).stdout.decode('utf-8','replace')
        if '<node' in x:
            return x
        time.sleep(1)
    return ''

def nos(x):
    for m in re.finditer(r'<node[^>]*>', x):
        n = m.group(0)
        def a(k):
            g = re.search(k + r'="([^"]*)"', n)
            return g.group(1) if g else ''
        rot = a('text') or a('content-desc')
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if not b:
            continue
        x1, y1, x2, y2 = map(int, b.groups())
        yield rot, (x1 + x2) // 2, (y1 + y2) // 2, a('class'), a('focused') == 'true'

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'ler'
    if cmd == 'escreve':
        subprocess.run(['adb','shell','input','text', sys.argv[2].replace(' ','%s')])
        return
    x = dump()
    if not x:
        print('SEM ÁRVORE — Select to Speak desligado?'); sys.exit(2)
    itens = [n for n in nos(x) if n[0].strip()]
    if cmd == 'toca':
        alvo = sys.argv[2].lower()
        for rot, cx, cy, _, _ in itens:
            if alvo in rot.lower():
                subprocess.run(['adb','shell','input','tap',str(cx),str(cy)])
                print(f'toquei em "{rot}" ({cx},{cy})'); return
        print(f'não encontrei "{sys.argv[2]}"'); sys.exit(1)
    vistos = set()
    for rot, cx, cy, cls, foco in itens:
        if rot in vistos: continue
        vistos.add(rot)
        print(f'{rot}\t({cx},{cy}){"\t[foco]" if foco else ""}')

main()
