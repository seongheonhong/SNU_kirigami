# SNU_kirigami

Software code repos. for the research on stretchable piezoelectric strain sensor with kirigami pattern.

## Matlab piezoelectric measurement simulator

Some researches miss the importance of measurement device.
Because piezoelectric generators(energy harvestor, sensors, etc.) contain its own resistance and capacitance,
measured voltage is highly affected by the total resistance and capacitance of measurement circuit.

Generally, voltmeters with low-price, high sample rate, high resolution tend to have low internal impedance, making them far from ideal voltmeter.
(e.g. NI-USB6009, Arduino UNO ADC, etc.)

This simulator will show how voltage profile differs depending on measurement devices(or circuits) with different specs.
