-- upstream: https://github.com/facebook/react/blob/8e5adfbd7e605bda9c5e96c10e015b3dc0df688e/packages/react-dom/src/client/ReactDOMComponentTree.js
--[[*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow
]]

local Workspace = script.Parent.Parent.Parent

local ReactRobloxHostTypes = require(script.Parent["ReactRobloxHostTypes.roblox"])
type HostInstance = ReactRobloxHostTypes.HostInstance;
type SuspenseInstance = ReactRobloxHostTypes.SuspenseInstance;

-- local type {Fiber} = require(Workspace.react-reconciler/src/ReactInternalTypes'
local ReactTypes = require(Workspace.Shared.ReactTypes)
type ReactScopeInstance = ReactTypes.ReactScopeInstance;
-- local type {
--   ReactDOMEventHandle,
--   ReactDOMEventHandleListener,
-- } = require(Workspace.../shared/ReactDOMTypes'
-- local type {
--   Container,
--   TextInstance,
--   Instance,
--   SuspenseInstance,
--   Props,
-- } = require(Workspace../ReactDOMHostConfig'

-- local {
--   HostComponent,
--   HostText,
--   HostRoot,
--   SuspenseComponent,
-- } = require(Workspace.react-reconciler/src/ReactWorkTags'

-- local {getParentSuspenseInstance} = require(Workspace../ReactDOMHostConfig'

-- local invariant = require(Workspace.shared/invariant'
-- local {enableScopeAPI} = require(Workspace.shared/ReactFeatureFlags'

local exports: {[any]: any} = {}

-- deviation: Use internal maps, since we can't set properties on Containers
-- (which are Instances). We might consider using the Attributes feature for
-- this when it releases
local containerToRoot: { [Container]: Fiber } = {}
local instanceToFiber: { [HostInstance | SuspenseInstance | ReactScopeInstance]: Fiber } = {}
local instanceToProps: { [HostInstance | SuspenseInstance]: Props } = {}

-- local randomKey = Math.random()
--   .toString(36)
--   .slice(2)
-- local internalInstanceKey = '__reactFiber$' + randomKey
-- local internalPropsKey = '__reactProps$' + randomKey
-- local internalContainerInstanceKey = '__reactContainer$' + randomKey
-- local internalEventHandlersKey = '__reactEvents$' + randomKey
-- local internalEventHandlerListenersKey = '__reactListeners$' + randomKey
-- local internalEventHandlesSetKey = '__reactHandles$' + randomKey

exports.precacheFiberNode = function(
  hostInst: Fiber,
  node: HostInstance | SuspenseInstance | ReactScopeInstance
)
  instanceToFiber[node] = hostInst
end

exports.markContainerAsRoot = function(hostRoot: Fiber, node: Container)
  -- deviation: Use our module-level map
  containerToRoot[node] = hostRoot
  -- node[internalContianerInstanceKey] = hostRoot
end

exports.unmarkContainerAsRoot = function(node: Container)
  -- deviation: Use our module-level map
  containerToRoot[node] = nil
  -- node[internalContainerInstanceKey] = nil
end

exports.isContainerMarkedAsRoot = function(node: Container): boolean
  -- deviation: Use our module-level map
  return not not containerToRoot[node]
  -- return not not node[internalContainerInstanceKey]
end

-- -- Given a DOM node, return the closest HostComponent or HostText fiber ancestor.
-- -- If the target node is part of a hydrated or not yet rendered subtree, then
-- -- this may also return a SuspenseComponent or HostRoot to indicate that.
-- -- Conceptually the HostRoot fiber is a child of the Container node. So if you
-- -- pass the Container node as the targetNode, you will not actually get the
-- -- HostRoot back. To get to the HostRoot, you need to pass a child of it.
-- -- The same thing applies to Suspense boundaries.
-- exports.getClosestInstanceFromNode(targetNode: Node): nil | Fiber {
--   local targetInst = (targetNode: any)[internalInstanceKey]
--   if targetInst)
--     -- Don't return HostRoot or SuspenseComponent here.
--     return targetInst
--   end
--   -- If the direct event target isn't a React owned DOM node, we need to look
--   -- to see if one of its parents is a React owned DOM node.
--   local parentNode = targetNode.parentNode
--   while (parentNode)
--     -- We'll check if this is a container root that could include
--     -- React nodes in the future. We need to check this first because
--     -- if we're a child of a dehydrated container, we need to first
--     -- find that inner container before moving on to finding the parent
--     -- instance. Note that we don't check this field on  the targetNode
--     -- itself because the fibers are conceptually between the container
--     -- node and the first child. It isn't surrounding the container node.
--     -- If it's not a container, we check if it's an instance.
--     targetInst =
--       (parentNode: any)[internalContainerInstanceKey] or
--       (parentNode: any)[internalInstanceKey]
--     if targetInst)
--       -- Since this wasn't the direct target of the event, we might have
--       -- stepped past dehydrated DOM nodes to get here. However they could
--       -- also have been non-React nodes. We need to answer which one.

--       -- If we the instance doesn't have any children, then there can't be
--       -- a nested suspense boundary within it. So we can use this as a fast
--       -- bailout. Most of the time, when people add non-React children to
--       -- the tree, it is using a ref to a child-less DOM node.
--       -- Normally we'd only need to check one of the fibers because if it
--       -- has ever gone from having children to deleting them or vice versa
--       -- it would have deleted the dehydrated boundary nested inside already.
--       -- However, since the HostRoot starts out with an alternate it might
--       -- have one on the alternate so we need to check in case this was a
--       -- root.
--       local alternate = targetInst.alternate
--       if 
--         targetInst.child ~= nil or
--         (alternate ~= nil and alternate.child ~= nil)
--       )
--         -- Next we need to figure out if the node that skipped past is
--         -- nested within a dehydrated boundary and if so, which one.
--         local suspenseInstance = getParentSuspenseInstance(targetNode)
--         while (suspenseInstance ~= nil)
--           -- We found a suspense instance. That means that we haven't
--           -- hydrated it yet. Even though we leave the comments in the
--           -- DOM after hydrating, and there are boundaries in the DOM
--           -- that could already be hydrated, we wouldn't have found them
--           -- through this pass since if the target is hydrated it would
--           -- have had an internalInstanceKey on it.
--           -- Let's get the fiber associated with the SuspenseComponent
--           -- as the deepest instance.
--           local targetSuspenseInst = suspenseInstance[internalInstanceKey]
--           if targetSuspenseInst)
--             return targetSuspenseInst
--           end
--           -- If we don't find a Fiber on the comment, it might be because
--           -- we haven't gotten to hydrate it yet. There might still be a
--           -- parent boundary that hasn't above this one so we need to find
--           -- the outer most that is known.
--           suspenseInstance = getParentSuspenseInstance(suspenseInstance)
--           -- If we don't find one, then that should mean that the parent
--           -- host component also hasn't hydrated yet. We can return it
--           -- below since it will bail out on the isMounted check later.
--         end
--       end
--       return targetInst
--     end
--     targetNode = parentNode
--     parentNode = targetNode.parentNode
--   end
--   return nil
-- end

-- --[[*
--  * Given a DOM node, return the ReactDOMComponent or ReactDOMTextComponent
--  * instance, or nil if the node was not rendered by this React.
--  ]]
-- exports.getInstanceFromNode(node: Node): Fiber | nil {
--   local inst =
--     (node: any)[internalInstanceKey] or
--     (node: any)[internalContainerInstanceKey]
--   if inst)
--     if 
--       inst.tag == HostComponent or
--       inst.tag == HostText or
--       inst.tag == SuspenseComponent or
--       inst.tag == HostRoot
--     )
--       return inst
--     } else {
--       return nil
--     end
--   end
--   return nil
-- end

-- --[[*
--  * Given a ReactDOMComponent or ReactDOMTextComponent, return the corresponding
--  * DOM node.
--  ]]
-- exports.getNodeFromInstance(inst: Fiber): Instance | TextInstance {
--   if inst.tag == HostComponent or inst.tag == HostText)
--     -- In Fiber this, is just the state node right now. We assume it will be
--     -- a host component or host text.
--     return inst.stateNode
--   end

--   -- Without this first invariant, passing a non-DOM-component triggers the next
--   -- invariant for a missing parent, which is super confusing.
--   invariant(false, 'getNodeFromInstance: Invalid argument.')
-- end

-- exports.getFiberCurrentPropsFromNode(
--   node: Instance | TextInstance | SuspenseInstance,
-- ): Props {
--   return (node: any)[internalPropsKey] or nil
-- end

exports.updateFiberProps = function(
  node: Instance | SuspenseInstance,
  props: Props
)
  instanceToProps[node] = props
end

-- exports.getEventListenerSet(node: EventTarget): Set<string> {
--   local elementListenerSet = (node: any)[internalEventHandlersKey]
--   if elementListenerSet == undefined)
--     elementListenerSet = (node: any)[internalEventHandlersKey] = new Set()
--   end
--   return elementListenerSet
-- end

-- exports.getFiberFromScopeInstance(
--   scope: ReactScopeInstance,
-- ): nil | Fiber {
--   if enableScopeAPI)
--     return (scope: any)[internalInstanceKey] or nil
--   end
--   return nil
-- end

-- exports.setEventHandlerListeners(
--   scope: EventTarget | ReactScopeInstance,
--   listeners: Set<ReactDOMEventHandleListener>,
-- ): void {
--   (scope: any)[internalEventHandlerListenersKey] = listeners
-- end

-- exports.getEventHandlerListeners(
--   scope: EventTarget | ReactScopeInstance,
-- ): nil | Set<ReactDOMEventHandleListener> {
--   return (scope: any)[internalEventHandlerListenersKey] or nil
-- end

-- exports.addEventHandleToTarget(
--   target: EventTarget | ReactScopeInstance,
--   eventHandle: ReactDOMEventHandle,
-- ): void {
--   local eventHandles = (target: any)[internalEventHandlesSetKey]
--   if eventHandles == undefined)
--     eventHandles = (target: any)[internalEventHandlesSetKey] = new Set()
--   end
--   eventHandles.add(eventHandle)
-- end

-- exports.doesTargetHaveEventHandle(
--   target: EventTarget | ReactScopeInstance,
--   eventHandle: ReactDOMEventHandle,
-- ): boolean {
--   local eventHandles = (target: any)[internalEventHandlesSetKey]
--   if eventHandles == undefined)
--     return false
--   end
--   return eventHandles.has(eventHandle)
-- end

return exports