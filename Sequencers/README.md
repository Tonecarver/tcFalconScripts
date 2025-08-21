# Notes for the Sequencer scripts

## Traveler

Scroll the mouse wheel in the grid to add/remove/modify rovers and obstacles in cells.

Rovers are green arrows that move through the grid at the clock rate and emit notes when striking a grid wall.

Obstacles remain stationary and affect rovers that encounter them. 

[UVi Falcon Script "Traveler" -- overview](https://www.youtube.com/watch?v=NTSy_tzMkiE)

## Turing Machine

Inspired by the various Turing Machine modules available for modular synthesis racks and VCV Rack. 

The Turing Machine is a binary shift register. The first few bits in the register provide a small random or semi-random number that determines which MIDI note is emitted at each step. The bits in the register are shifted, recirculated, and randomly modified to produce a random or semi-random sequence of values.

The Turing Machine is another "happy accident" machine. Sequences evolve and play within the configured and interactive guidelines and guard rails. 

Overview video: [Turing Machine for UVI Falcon](https://www.youtube.com/watch?v=CjORRqz0anI)

The general concepts behind a Turing Machine module: [Turing 201: Turing Machine Explained! (More than you ever needed to know...)](https://www.youtube.com/watch?v=va2XAdFtmeU)


