// Copyright 2009-2020 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "Geometry.h"

namespace ospray {

struct OSPRAY_SDK_INTERFACE Ellipsoids : public Geometry
{
  Ellipsoids();
  virtual ~Ellipsoids() override = default;

  virtual std::string toString() const override;

  virtual void commit() override;

  virtual size_t numPrimitives() const override;

 protected:
  Ref<const DataT<vec3f>> radii{0.01, 0.02, 0.03};
  Ref<const DataT<vec3f>> vertexData;
  Ref<const DataT<vec3f>> radiiData;
  Ref<const DataT<vec2f>> texcoordData;
};

} // namespace ospray
