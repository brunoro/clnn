require 'clnn'

function graphGetNodes(g)
--  g2 = g:clone()
  g2 = g
  newbg = g2.bg.nodes[2]
  thisnode = newbg
  x = newbg
  while #thisnode.children > 0 do
    x = thisnode
    thisnode = thisnode.children[1]
  end

  thisnode = newbg
  while thisnode.data ~= x.data do
    thisnode = thisnode.children[1]
  end
  thisnode.children = {}

  for i, node in ipairs(newbg:graph().nodes) do
    node.data.mapindex = {}
    print('node i', i, node.data.module)
    for j, child in ipairs(node.children) do
      node.data.mapindex[#node.data.mapindex + 1] = child.data
      node.data.mapindex[child.data] = #node.data.mapindex
    end
    for k,v in pairs(node.data.mapindex) do
      print('k', torch.type(k), 'v', torch.type(v))
    end
  end

  return x, newbg
end

function removeNodeByWalk(node, data)
  print('removeNodeByWalk', node.data.annotations.name)
  if node.data == data then
    -- its me!
    assert(#node.children == 1)
    return node.children[1]
  end
  for i, child in ipairs(node.children) do
    if child.data == data then
      print('remove child', i, child.data.annotations)
      table.remove(node.children, i)
      node.children[child] = nil
      local childmapindexidx = node.data.mapindex[child.data]
      node.data.mapindex[childmapindexidx] = nil
      node.data.mapindex[child.data] = nil
      for j, childchild in ipairs(child.children) do
        if node.children[childchild] == nil then
          table.insert(node.children, childchild)
          node.children[childchild] = #node.children
          node.data.mapindex[childchild.data] = #node.data.mapindex + 1
          node.data.mapindex[#node.data.mapindex + 1] = childchild.data
        end
      end
    end
  end
  for i, child in ipairs(node.children) do
    removeNodeByWalk(child, data)
  end
  return node
end

--local n = nn.Apply(3, 2, [[
--  {{out1}} = {{in1}} + {{in2}};
--  {{out2}} = {{in3}} + 3.0f;
--]], [[
--  {{in1}} = {{out1}};
--  {{in2}} = {{out1}};
--  {{in3}} = {{out2}};
--]])

local in1 = torch.ClTensor(3,2):uniform()
local in2 = torch.ClTensor(3,2):uniform()
local in3 = torch.ClTensor(3,2):uniform()
local inputs = {in1, in2, in3}

--local outputs = n:forward(inputs)
--print('in1', in1)
--print('in2', in2)
--print('in3', in3)
--print('outputs\n', outputs, outputs[1], outputs[2])

--local gradInput = n:backward(inputs, outputs)
--print('gradInput\n', gradInput, gradInput[1], gradInput[2], gradInput[3])


require 'nngraph'
local x = nn.Identity()()
local m1 = nn.Tanh()(x)
local m2 = nn.Sigmoid()(m1)
--local m3 = nn.Tanh()(m2)
g = nn.gModule({x}, {m2})
g2 = g:clone()
g:cl()
g2:cl()

local output1 = g:forward(inputs[1])

graph.dot(g.fg, '', 'g.fg')

for i, node in ipairs(g2.forwardnodes) do
  print(i, node, node.id)
  local moduletype = torch.type(node.data.module)
  if moduletype == 'nn.Tanh' then
    print('Tanh detected')
    local apply = nn.Apply(1, 1, [[
      {{output}} = tanh({{input}});
    ]], [[
      {{gradInput}} = {{gradOutput}} * (1 - {{output}} * {{output}});
    ]])
    node.data.module = apply
  elseif moduletype == 'nn.Sigmoid' then
    print('Sigmoid detected')
    local apply = nn.Apply(1, 1, [[
      {{output}} =  1.f / (1.f + exp( - {{input}}));
    ]], [[
      {{gradInput}} = {{gradOutput}} * {{output}} * (1.f - {{output}});
    ]])
    node.data.module = apply
    print('node.data.module', node.data.module)
  end
end

graph.dot(g2.fg, '', 'g2.fg')

local output2 = g2:forward(inputs[1])
print('output1', output1)
print('output2', output2)
local diff = (output2 - output1):abs():sum()
print('diff', diff)
assert(diff == 0)

local gradInput1 = g:backward(inputs[1], output1)
print('gradInput1\n', gradInput1)

local gradInput2 = g2:backward(inputs[1], output1)
print('gradInput2\n', gradInput2)

diff = (gradInput2 - gradInput1):abs():sum()
print('diff', diff)
assert(diff == 0)

os.exit(0)

function isApply(module)
  if torch.type(module) == 'nn.Apply' then
    return true
  end
  return false
end

x3, nodes3 = graphGetNodes(g2)
-- fuse them...
-- for now, let's just look for a parent-child who are both applies, and fuse those
local didfuse = true
local fuseid = 1
while didfuse do
  didfuse = false
  ng3bg = nodes3:graph() -- not an nngraph, just a normal graph
  ng3fg = ng3bg:reverse()
  local n1 = nil
  local n2 = nil -- this is the second, that eats the first
  local n1_pos = nil
--  local n2_pos = nil
  for i, node in ipairs(ng3fg.nodes) do
    if n1 == nil then  -- since no 'break'
      print('i', i, node.data.module)
      if isApply(node.data.module) then
        for j, child in ipairs(node.children) do  -- I know this is rubbish n-squared, fix this later..
          if i1 == nil then
            if isApply(child.data.module) then
              n1 = node
              n2 = child
              n1_pos = i
            end
          end
        end
      end
    end
  end

  if n1 ~= nil then
    print('fusing... ==============================')
    local n1_forward = n1.data.module.forwardExpression
    local n2_forward = n2.data.module.forwardExpression
    print('n1 forward', n1_forward)
    print('n2 forward', n2_forward)

    tempvar = 'sOutput' .. fuseid
    fuseid = fuseid + 1
    n1_forward = n1_forward:gsub('{{output}}', 'float ' .. tempvar)
    n2_forward = n2_forward:gsub('{{input}}', tempvar)

    print('n1 forward', n1_forward)
    print('n2 forward', n2_forward)

    local fused_forward_exp = n1_forward .. '\n' .. n2_forward
    print('fused_forward', fused_forward_exp)

    -- calculate forward first, to get the output values
    -- do this by adding hte fused_forward_exp at the start
    tempvar = 'sGradInput' .. fuseid
    local n1_backward = n1.data.module.backwardExpression
    local n2_backward = n2.data.module.backwardExpression
    print('n1 backward', n1_backward)
    print('n2 backward', n2_backward)
    n2_backward = n2_backward:gsub('{{gradInput}}', 'float ' .. tempvar)
    n1_backward = n1_backward:gsub('{{gradOutput}}', tempvar)

    local fused_backwardonly_exp = n2_backward .. '\n' .. n1_backward
    print('fused_backward', fused_backwardonly_exp)

    local forward_then_backward = fused_forward_exp .. '\n' .. fused_backwardonly_exp

    local fusedModule = nn.Apply(1, 1, fused_forward_exp, forward_then_backward)
    fusedModule.backwardOnlyExpression = fused_backwardonly_exp
    nodes3 = removeNodeByWalk(nodes3, n2.data)
    n1.data.module = fusedModule
    fusedModule.inputsNeeded = fusedModule.inputsNeeded or {}
    fusedModule.gradOutputsNeeded = fusedModule.gradOutputsNeeded or {}
    fusedModule.gradOutputsNeeded[n2.id] = true
    fusedModule.gradOutputsNeeded[n1.id] = nil
--    table.insert(fusedModule.inputsNeeded, {id=)
    didfuse = true
  end
end

graph.dot(nodes3:graph(), '', 'nodes3')

g3 = nn.gModule({x3}, {nodes3})

graph.dot(g3.fg, '', 'g3.fg')

print('input', inputs[1])

output2 = g3:forward(inputs[1])
print('output1', output1)
print('output2', output2)
diff = (output2 - output1):abs():sum()
print('diff', diff)
assert(diff == 0)

local gradInput2 = g3:backward(inputs[1], output1)
print('gradInput2\n', gradInput2)

diff = (gradInput2 - gradInput1):abs():sum()
print('diff', diff)
assert(diff == 0)
