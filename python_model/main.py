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
            assert 'id' in n and 'threshold' in n and 'leak' in n and 'inhibit' in n
            assert n['id'] >= 0 and n['id'] <= 15
            assert n['threshold'] >= 0 and n['threshold'] <= 15
            assert n['leak'] >= -2 and n['leak'] <= 1
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
    Neurons = load_neurons('fizzbuzz.json', 'crossbar.json')
    numSpikes = [0]*len(Neurons)
    if len(sys.argv) > 1:
        ticks = int(sys.argv[1])
    else:
        ticks = 1000
    for tick in range(ticks):
        print(f'TICK: {tick}')
        for N in Neurons:
            N.tick()
        for n, N in enumerate(Neurons):
            N.spike_writeback()
            print(f'\tNEURON: {n}')
            print(f'\t\tSPIKE: {N.spike}')
            print(f'\t\tPOTENTIAL: {N.potential}')
            if N.spike:
                numSpikes[n] += 1
    print(numSpikes)
    
# main execution
if __name__ == '__main__':
    main()