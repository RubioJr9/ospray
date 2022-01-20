// Copyright 2009-2021 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

// ospray
#include "Ellipsoids.h"
#include "common/Data.h"
#include "common/World.h"
// ispc-generated files
#include "geometry/Ellipsoids_ispc.h"

namespace ospray {

Ellipsoids::Ellipsoids()
{
  ispcEquivalent = ispc::Ellipsoids_create();
}

std::string Ellipsoids::toString() const
{
  return "ospray::Ellipsoids";
}

void Ellipsoids::commit()
{
  if (!embreeDevice) {
    throw std::runtime_error("invalid Embree device");
  }
  if (!embreeGeometry) {
    embreeGeometry = rtcNewGeometry(embreeDevice, RTC_GEOMETRY_TYPE_USER);
  }
  radii = getParam<vec3f>("radii", {0.01f, 0.02f, 0.03f});
  vertexData = getParamDataT<vec3f>("ellipsoid.position", true);
  radiiData = getParamDataT<vec3f>("ellipsoid.radii");
  texcoordData = getParamDataT<vec2f>("ellipsoid.texcoord");

  ispc::EllipsoidsGeometry_set(getIE(),
      embreeGeometry,
      ispc(vertexData),
      ispc(radiiData),
      ispc(texcoordData),
      ispc(radii));

  postCreationInfo();
}

size_t Ellipsoids::numPrimitives() const
{
  return vertexData ? vertexData->size() : 0;
}

} // namespace ospray
