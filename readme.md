
<p align="center">  
  <img width="25%" src="https://github.com/user-attachments/assets/808c1e9f-f0ad-44bf-9728-00b3a283ace9">
  <h3 align=center></h3>
</p>

![buildworkflow](https://github.com/foxnne/pixi/actions/workflows/build.yml/badge.svg)

# 
**Pixi** is an cross-platform open-source pixel art editor and animation editor written in [Zig](https://github.com/ziglang/zig).

#### Check out the [user guide](https://github.com/foxnne/pixi/wiki/User-Guide)!

![pixi_explanatory_workflow](https://github.com/foxnne/pixi/assets/49629865/51e16f4d-634e-461d-ba5e-41cc4fa8229e)

<img width="1468" alt="Screenshot 2023-08-09 at 1 15 03 AM" src="https://github.com/foxnne/pixi/assets/49629865/eaee91b2-5844-4e2e-a776-867a307cde7f">

<img width="1468" alt="Screenshot 2023-08-09 at 1 12 48 AM" src="https://github.com/foxnne/pixi/assets/49629865/ed106b13-7a63-4538-b0a3-60daba0a8093">


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

## User Interface
- The user interface is driven by [Dear Imgui](https://github.com/ocornut/imgui) which should be familiar to many.
- The general layout takes many ideas from VSCode, as well as general project setup using folders.

## Compilation
- [Linux] Ensure `gtk+3-devel` or similar is installed (for native file dialogs).
- Install zig using [zigup](https://github.com/marler8997/zigup) `zigup 0.14.0-dev.2577+271452d22` or manually and add to PATH.
- Zig version required is latest mach nominated version, find [here.]https://machengine.org/docs/nominated-zig/#2024110-mach(https://machengine.org/docs/nominated-zig/#2024110-mach)
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


     
