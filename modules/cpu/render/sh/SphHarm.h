// Copyright 2020 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

// ospray
#include "render/Renderer.h"
// ispc shared
#include "SphHarmShared.h"

namespace ospray {

struct SphHarm : public AddStructShared<Renderer, ispc::SphHarm>
{
  SphHarm();
  std::string toString() const override;
  void commit() override;
  void *beginFrame(FrameBuffer *, World *) override;
};

} // namespace ospray
