class SpikingNeuron(object):
    # Create SpikingNeuron object
    # The configurable parts of a SpikingNeuron are threshold, leak, inhibit
    # potential is initialized to 0, spike is initialized to false
    def __init__(self, id, threshold, leak, inhibit):
        self.id = id
        self.threshold = threshold
        self.leak = leak
        self.inhibit = inhibit
        self.potential = 0
        self.spike = False
        self.spike_next = False
        self.axons = []
    
    # Adding axon connection to this neuron
    # This is done by giving a reference to another SpikingNeuron object
    def add_axon(self, axon):
        self.axons.append(axon)
     
    # Wrapper function for incrementing potential
    # Prevents overflow (addition would result in potential > 15) and underflow (addition would result in potential < 0)
    # In these cases of overflow/underflow, we would just not make the addition   
    def add_pot(self, add):
        new_pot = self.potential + add
        if new_pot > 15 or new_pot < 0:
            return
        self.potential = new_pot
    
    # Leak neuron
    def do_leak(self):
        self.add_pot(self.leak)
    
    # Tick for current neuron    
    def tick(self):
        # Iterate over all axon connections
        for axon in self.axons:
            # Axon connection wants to send spike
            if axon.spike:
                add = -1 if axon.inhibit else 1 
                self.add_pot(add)
        # Current neuron leaks
        self.do_leak()
        # Determine if current neuron wants to spike on next tick
        if self.potential >= self.threshold:
            self.spike_next = True
            self.potential -= self.threshold
        else:
            self.spike_next = False
            
    # Prepare spike for next tick
    def spike_writeback(self):
        self.spike = self.spike_next