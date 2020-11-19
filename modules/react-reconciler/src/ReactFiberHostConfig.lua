-- upstream: https://github.com/facebook/react/blob/9ac42dd074c42b66ecc0334b75200b1d2989f892/packages/react-reconciler/src/ReactFiberHostConfig.js
--[[*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @flow
]]

--[[ eslint-disable react-internal/invariant-args ]]

local Workspace = script.Parent.Parent

local invariant = require(Workspace.Shared.invariant)

-- We expect that our Rollup, Jest, and Flow configurations
-- always shim this module with the corresponding host config
-- (either provided by a renderer, or a generic shim for npm).
--
-- We should never resolve to this file, but it exists to make
-- sure that if we *do* accidentally break the configuration,
-- the failure isn't silent.

-- deviation: FIXME (roblox): is there a way to configure luau to account for this module
-- being shimmed?
export type Instance = any;
export type TextInstance = any;
export type Container = any;
export type PublicInstance = any;
export type RendererInspectionConfig = any;
export type SuspenseInstance = any;

invariant(false, 'This module must be shimmed by a specific renderer.')