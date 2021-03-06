# clnn

OpenCL backend for Torch nn neural networks library.

## What works

### Parameterized Modules
* nn.Linear

### Basic Tensor methods

These mostly 'just work', since based on underlying tensor methods, already implemented in [cltorch](https://github.com/hughperkins/cltorch).  Tested with:

* nn.Narrow

### Miscellaneous modules

* nn.Identity
* nn.Dropout

### Convolution layers

* nn.SpatialConvolutionMM
* nn.SpatialMaxPooling (note: half the pooling size should be no greater than stride currently, though easy to fix this, so please log an issue if you need)
* nn.SpatialAveragePooling (either filter size must equal input size, or filter size must equal stride size)

### Transfer function layers

* nn.Tanh
* nn.Sigmoid
* nn.ReLU
* nn.Exp
* nn.Sqrt
* nn.Square
* nn.Abs
* nn.LogSigmoid
* nn.HardTanh
* nn.LogSoftMax (mini-batches only, ie expects to receive a 2d ClTensor)

### Table layers

These 'just work', since they are based on underlying torch operations, which are already implemented in [cltorch](https://github.com/hughperkins/cltorch).  Tested with:
* nn.CMulTable
* nn.CAddTable

### Criterions

* nn.MSECriterion
* nn.ClassNLLCriterion

### Containers:

Containers 'just work', since they just call standard operations on the contained modules.  Tested with:
* nn.Sequential
* nngraph

### Trainers

Trainers 'just work', since they just call standard methods on the network to be trained.  Tested with:
* nn.StochasticGradient
* optim

## Timings

### Mnist

Using the network in [test/test-mnist2.lua](test/test-mnist2.lua), and `MODEL=conv1`, following timings using an NVidia 940M, per epoch:
* `API=cuda`: 3.2 seconds
* `API=cl`: 13.6 seconds

Note that this network is a bit unfair on clnn, since these are really tiny layers and inputs, for which clnn does less well currently, see the table in 'Soumith benchmark layers', below.

(hmmm, interestingly, on this tiny network, [DeepCL](https://github.com/hughperkins/DeepCL) is actually faster than both.  2.3 seconds per epoch, using `./train numtrain=5120 numtest=-1 netdef=32c5-tanh-mp3-64c5-tanh-mp2-200n-tanh-10n`.)

### Soumith benchmark layers

On an NVidia 940M, using [test/test-perf.lua](test/test-perf.lua):

| layer | direction | cuda time (seconds) | cl time (seconds) |
|-------|-----------|---------------------|----------------|
| l1    | forward   | 1.02               | 1.14    |
| l2    | forward   | out of mem          | out of mem     |
| l3    | forward   | 0.85                | 1.19 |
| l4    | forward   | 0.15                | 0.42 |
| l5    | forward   | 0.22                | 0.37 |

| layer | direction | cuda time (seconds) | cl time (seconds) |
|-------|-----------|---------------------|----------------|
| l1    | backward  | 0.93+1.47 =2.4              | 1.25+1.43 = 2.68    |
| l2    | backward   | didnt try          | didnt try    |
| l3    | backward   | 0.84+0.64 =1.48                | 0.93+2.28=3.21 |
| l4    | backward   | 0.11+0.11 =0.22               | 0.17+0.20=0.37 |
| l5    | backward   | 0.13+0.16=0.29                | 0.23+0.91=1.14 |

## Example network

* Here is an OpenCL-enabled version of Karpathy's LSTM network: [https://github.com/hughperkins/char-rnn](https://github.com/hughperkins/char-rnn)
* Simply add option `-opencl 1` to enable OpenCL :-)
* Current comparison, using an NVidia 940M graphics card, and an Intel i5-5200U processor.  These are timings per-batch
  * cpu: 3.4s
  * clnn: 0.27s
  * cunn: 0.13s

## Installation

### Pre-requisites

* have installed:
  * [torch](https://github.com/torch/torch7)
  * [nn](https://github.com/torch/nn)
  * [cltorch](https://github.com/hughperkins/cltorch)
* have updated, right now, cltorch, to latest version, eg `luarocks install cltorch`
  * any weird build issues on clnn, or seg faults etc, please verify cltorch is latest version before raising issue
* have an OpenCL-enabled GPU device available, and appropriate OpenCL-enabled drivers installed

### Procedure

```
git clone https://github.com/hughperkins/clnn.git
cd clnn
luarocks make rocks/clnn-scm-1.rockspec
```

You should now be able to use `require 'clnn'` from your lua scripts :-)

## Updating

* Please update to latest version of cltorch before updating to latest version of clnn
* If you update cltorch, please afterwards also update clnn

## Unit-tests

* For all layers except SpatialConvolutionMM, please see:
  * [test/test-layers.lua](test/test-layers.lua)
* For SpatialConvolutionMM, please see:
  * [test/test-spatialconvolution.lua](test/test-spatialconvolution.lua) (Needs `cunn` available, to do numerical comparison)

## Porting guidelines

Porting guidelines, for project maintainers, available here: [porting-guidelines.md](doc/porting-guidelines.md).

## Recent changes

* 10th August:
  * Improve error message when out of memory, ie will say it ran out of memory, rather than say 'c++ exception' now, in many common cases
  * SpatialMaxPooling can now handle pooling size and stride are different, as long as half the pooling size is no more than stride
  * Added SpatialAveragePooling for case where input size equals filter size, or filter size equals stride size
* 22nd July:
  * Performance improvements in underlying [cltorch](https://github.com/hughperkins/cltorch) mean that times for [char-rnn](http://github.com/karpathy/char-rnn) are now around 2-3 times faster on NVIDIA and AMD GPUs
* 6th July:
  * lots of new activations added: `Sqrt`, `Square`, `Exp`, `Abs`, `LogSigmoid`, `HardTanh`  (provided by Sergey Zagoruyko)
  * SpatialMaxPooling:
    * added implicit floor max pooling (provided by Sergey)
    * added 3d forward (from Sergey)
  * added tests from cunn (thank you Sergey)
  * bug fixes:
    * SpatialConvolutionMM updated to match current nn (Sergey)
    * fixed bug in ReLU for in-place forward
* 27th June:
  * mild perf improvement to LogSoftMax layer
  * removed FullyConnected for now
  * mild perf improvement to Narrow layer
  * huge perf improvement :-)  Please update to latest version of [cltorch](http://github.com/hughperkins/cltorch) (should be at least commit 2f1e3e758fb or later)
* 26th June:
  * fixed bug in Sigmoid, which wasnt resizing correctly
* 25th June:
  * added tests for CMulTable and CAddTable, which pass
  * added test for Narrow, which passes
  * fix bug in cmakelists.txt, which meant that installation didnt work (it ran ok for me, so I didnt notice...)
  * Dropout working now
* 24th June:
  * Added ClassNLLCriterion layer (and unit tests for this)
* 23rd June:
  * Added LogSoftMax layer (and unit test for this)
* 22nd June:
  * Checked that SpatialConvolutionMM gives same results using clnn, compared with cunn
  * Checked that SpatialMaxPooling gives same results using clnn, compared with nn
  * Added ReLU, which was already marked as added but ... wasnt :-P  but now is :-) )
* 21st June:
  * Got SpatialConvolutionMM and SpatialMaxPooling running
  * Ran Soumith benchmarks on SpatialConvolutionMM, for clnn and cunn, on NVidia 940M

