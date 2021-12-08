import json
import sys
from time import sleep
from SpikingNeuron import SpikingNeuron

# checks to make sure neuron json file is done correctly
# ie, must have 16 neurons that all have
#   threshold -> [0, 15]
#   leak -> [-1, 2]
#   inhibit -> boolean (true if the neuron will inhibit, false if the neuron will enhance)
def neuron_integrity(neurons):
    try:
        assert len(neurons) == 16
        for n in neurons:
            assert 'threshold' in n and 'leak' in n and 'inhibit' in n
            assert n['threshold'] >= 0 and n['threshold'] <= 15
            assert n['leak'] >= -1 and n['leak'] <= 2
            assert type(n['inhibit']) == bool
    except AssertionError:
        print('Bad neuron file')
        sys.exit(1)

# checks to make sure crossbar file is done correctly
# ie, must specify connections for all 16 neurons and each connection be in the range [0, 15] (index of axon to connect to)
def crossbar_integrity(crossbar):
    try:
        assert len(crossbar) == 16
        for connections in crossbar:
            for c in connections:
                assert c >= 0 and c <= 15
    except AssertionError:
        print('Bad crossbar file')
        sys.exit(2)

# Load in neurons, crossbar connections from json files
def load_neurons(neurons, crossbar):
    # Load in properties of neurons
    neurons_in = json.load(open(neurons))
    neuron_integrity(neurons_in)
    # Load in crossbar connections
    crossbar_in = json.load(open(crossbar))
    crossbar_integrity(crossbar_in)
    # Create array of Neurons
    Neurons = [ SpikingNeuron(**n) for n in neurons_in ]
    # Add crossbar connections, done by adding references to other SpikingNeuron objects
    for n, connections in enumerate(crossbar_in):
        for c in connections:
            Neurons[n].add_axon(Neurons[c])
    return Neurons

# main driver
def main():
    Neurons = load_neurons('neurons.json', 'crossbar.json')
    iteration = 0
    while True:
        print(f'TICK: {iteration}')
        for N in Neurons:
            N.tick()
        for n, N in enumerate(Neurons):
            N.spike_writeback()
            print(f'\tNEURON: {n}')
            print(f'\t\tSPIKE: {N.spike}')
            print(f'\t\tPOTENTIAL: {N.potential}')
        iteration += 1
        sleep(3)
    
# main execution
if __name__ == '__main__':
    main()