# GridNorth
### CSE 40462 Final Project
##### Bryan Ingwersen, Jake Leporte, Martin Dawson, Patrick Harkins

> Guided by the principles of biological neural computation, neuromorphic computing intentionally departs from the familiar algorithms and programming abstractions of conventional computing so it can unlock orders of magnitude gains in efficiency and performance compared to conventional architectures.

This project contains a model for a Spiking Neural Network (SNN) - an AI architecture that mimics the structure of biological neural networks.  Our architecture, inspired by the architecture and design of IBM TrueNorth, is called **GridNorth**.  **GridNorth** is a nertwork of 16 spiking neurons, which each have their own logic and can communicate using their spikes.

This project contains 2 models of **GridNorth**: a Verilog structural model and a python3 behavioral model.

## Verilog Model

The Verilog model, built using [Makerchip](https://makerchip.com/), is entirely made up of structural blocks.  That is, all the modules contained within are either primitive gates (and, or, not, xor, etc) or built from primitive gates.  All the high level architectual modules can be boiled down to simple logic gates.  We also used the Quartus tool for testing and to generate netlists of our architecture (see `presentation/figures`).  Also see the testbenches we wrote to test the controller and our FizzBuzz solution.

## Python Model

In order to test our SNN model, we also created a python model.  This model is driven by the `SpikingNeuron` class, which can emulate the behavior of a single **GridNorth** neuron.  The output can be seen in the _spike buffer_: which is simply an array denoting how many times each neuron spiked over the course of execution.

### Usage

Running a python test of a network you have in mind is incredibly simple and configurable.  All you have to do is edit 2 json files - the neuron configuration and the crossbar configuration.  The configurable parts of a neuron are:
1. `threshold` \[0 - 15].  The neuron will spike if its potential is >= its threshold
2. `leak` \[-2 - 1].  On each tick, the neuron will add this value to its potential
3. `inhibit` \[boolean].  True if this neuron will _inhibit_ neurons it spikes, false if it will _enhance_.
* When a neuron recieves a spike, it will either add 1 to its potential (the neuron that spiked is _enhancing_)
* Or it will substract 1 from its potential (the neuron that spiked is _inhibiting_)

Configuring the crossbar connections is as simple as indexing other neurons in the list.  All you need to do in the crossbar configurtation file is add the neuron id's that each neuron has a crossbar connection to.  NOTE: In our architecture, spikes are recieved, not sent. I.e. if you want Neuron 0 and Neuron 1 to spike Neuron 4, you edit Neuron 4's crossbar (the 5th one down) to read `[0, 1]`.

See `presentation/figues/fizzbuzz.png`, `python_model/fizzbuzz.json`, and `python_model/crossbar.json` to see how we set up the json configuration to solve fizzbuzz.

Usage: `$ python3 main.py number-of-ticks neurons-config-json crossbar-config-json`
Using without argv arguments will result in 1000 ticks, fizzbuzz.json, and crossbar.json.
The program will result in error if the incorrect number of arguments are used or the jsons are not configured correctly.