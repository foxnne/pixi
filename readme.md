
<p align="center">  
  <img width="25%" src="https://github.com/user-attachments/assets/fa4adcf9-6b59-49f9-8dd9-e8851ab0192d">
  <h3 align=center></h3>
</p>

![buildworkflow](https://github.com/foxnne/pixi/actions/workflows/build.yml/badge.svg)

# 
**Pixi** is an cross-platform open-source pixel art editor and animation editor written in [Zig](https://github.com/ziglang/zig).

#### Check out the [user guide](https://github.com/foxnne/pixi/wiki/User-Guide)!


![Pixi-FileExplorer](https://github.com/user-attachments/assets/b69bd3f5-d387-4a51-8767-d29179cd3061)
![Pixi-TabSplits](https://github.com/user-attachments/assets/8d947fe8-3dec-45fc-9550-0a250981895d)


<img width="1312" height="940" alt="Screenshot 2025-07-18 at 8 45 53 AM" src="https://github.com/user-attachments/assets/639d978a-334e-45f9-a9d2-e167463f82aa" />


[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R5R4LL2PJ)

## Currently supported features
- [x] Typical pixel art operations. (draw, erase, dropper, bucket, selection, transformation, etc)
- [x] Create animations and preview easily, edit directly on the preview.
- [x] View previous and next frames of the animation.
- [x] Set sprite origins for drawing sprites easily in game frameworks.
- [x] Import and slice existing .png spritesheets.
- [x] Intuitive and customizeable user interface.
- [x] Sprite packing
- [x] Theming
- [x] Automatic packing and export on file save
- [x] Also a zig library offering modules for handling assets
- [x] NEW: Export animations as .gifs 

## User Interface
- The user interface is driven by [Dear Imgui](https://github.com/ocornut/imgui) which should be familiar to many.
- The general layout takes many ideas from VSCode, as well as general project setup using folders.

## Compilation
- [Linux] Ensure `gtk+3-devel` or similar is installed (for native file dialogs).
- Install zig 0.15.1.
- Clone pixi.
- Build.
    - ```git clone https://github.com/foxnne/pixi.git```
    - ```cd pixi```
    - ```zig build run```

## Credits
- The wonderful [Dear Imgui](https://github.com/ocornut/imgui) used for almost all of the user interface.
- [emidoots](https://github.com/emidoots) for all the help and [mach](https://github.com/hexops/mach).
- [michal-z](https://github.com/michal-z) for all the help and [zig-gamedev](https://github.com/michal-z/zig-gamedev).
- [prime31](https://github.com/prime31) for all the help.
- Any and all contributors


     
