
<p align="center">  
  <img width="25%" src="assets/Icon1024.png">
  <h3 align=center></h3>
</p>

# 
**Pixi** is an cross-platform open-source pixel art editor and animation editor written in [Zig](https://github.com/ziglang/zig).

#### Pixi is currently undergoing a full rewrite, and will hopefully be a more useful and less buggy program soon.

<img width="1392" alt="Screen Shot 2022-10-18 at 12 56 53 AM" src="https://user-images.githubusercontent.com/49629865/196347392-f645c7c7-4887-4c6b-af26-b7c69af188ff.png">

# 

<img width="1392" alt="Screen Shot 2022-10-18 at 12 57 10 AM" src="https://user-images.githubusercontent.com/49629865/196347461-04a66eb8-c109-430d-b565-e51b5013e8ba.png">

## Features planned for 0.1
- [ ] Typical pixel art operations. (draw, erase, color select)
- [ ] Create animations and preview easily, edit directly on the preview.
- [ ] View previous and next frames of the animation.
- [ ] Set sprite origins for drawing sprites easily in game frameworks.
- [ ] Import and slice existing .png spritesheets.
- [x] Intuitive and customizeable user interface.
- [ ] Sprite packing

## User Interface
- The user interface is driven by [Dear Imgui](https://github.com/ocornut/imgui) which should be familiar to many.
- The general layout takes many ideas from VSCode, as well as general project setup using folders.

## Planned Features

- Export/import options.
    - Possibly .pyxel and .asesprite import
    - Export to .zig to directly use in Zig frameworks
    - .gif support
- Palettes
- Tiles 
- Possibly much more

## Compilation
- Download the latest Zig master from [here](https://ziglang.org/download/) and add to PATH.
- Clone pixi.
- Build.
    - ```git clone https://github.com/foxnne/pixi.git --recursive```
    - ```cd pixi```
    - ```zig build run```


## Credits
- The wonderful [Dear Imgui](https://github.com/ocornut/imgui) used for almost all of the user interface.
- [michal-z](https://github.com/michal-z) for all the help and [zig-gamedev](https://github.com/michal-z/zig-gamedev) which does all the heavy lifting.
- [prime31](https://github.com/prime31) for all the help.
- Any and all contributors


     






