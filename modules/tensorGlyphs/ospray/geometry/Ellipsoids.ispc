// Copyright 2009-2021 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

// ospray
#include "common/Data.ih"
#include "common/FilterIntersect.ih"
#include "common/ISPCMessages.h"
#include "common/Intersect.ih"
#include "common/Ray.ih"
#include "common/World.ih"
#include "geometry/Geometry.ih"
#include "math/sampling.ih"
#include "rkcommon/math/sampling.ih"
#include "rkcommon/math/box.ih"
#include "rkcommon/math/vec.ih"

struct Ellipsoids
{
  Geometry super;
  Data1D vertex;
  Data1D radii;
  Data1D texcoord;
  vec3f global_radii;
};

// robust ray-ellipsoid intersection
inline Intersections intersectEllipsoid(const vec3f &rayOrg,
    const vec3f &rayDir,
    const uniform vec3f &center,
    const uniform vec3f &radii)
{
  Intersections isect;
  isect.entry.hit = false;
  isect.exit.hit = false;
  isect.entry.t = inf;
  isect.exit.t = -inf;

  const vec3f d = rayDir;
  const float rd2 = 1.0f / dot(d, d); // 1/a
  const vec3f CO = center - rayOrg;
  // transformation to avoid missing a small sphere which is far away:
  // the standard c=CO^2-r^2 would quickly loose term r due to float arithmetic
  const float projCO = dot(CO, d) * rd2; // in ray-space
  const vec3f perp = CO - projCO * d;
  const float l2 = dot(perp, perp);
  const uniform float r2 = sqr(radii.x);
  if (l2 > r2)
    return isect;
  float td = sqrt((r2 - l2) * rd2);
  isect.entry.hit = true;
  isect.exit.hit = true;
  isect.entry.t = projCO - td;
  isect.exit.t = projCO + td;

  // above solutions are problematic if rays starts close to the sphere
  // (due to catastrophic cancellation, because then |projCO| ~ td)
  // the usual recommendation is to choose the one solution with same sign:
  //   const float t1 = projCO + floatbits(signbits(projCO)|intbits(td));
  // and compute the other solution via t1*t2=c/a:
  //   const float t2 = (dot(CO, CO) - r2) / t1 * rd2;
  // this is more precise, but still problematic in particular for large
  // spheres, because |CO| ~ r; slightly better alternative, but costly sqrt:
  //   const float f = sqrt(dot(CO, CO));
  //   const float t2 = (f - radius) * (f + radius) / t1 * rd2;
  // the only variant I found that has high enough precision to avoid
  // self-intersections of 2ndary rays is to (re-)compute most terms (CO, dot,
  // r2, t2) with doubles; large spheres are a rare usecase for OSPRay, thus we
  // use instead as a workaround an additional, radius-dependent epsilon

  // cannot easily be moved to postIntersect
  // we need hit in object space, in postIntersect it is in world-space
  isect.entry.N = -td * d - perp;
  isect.exit.N = td * d - perp;

  return isect;
}

static void Ellipsoids_postIntersect(const Geometry *uniform geometry,
    varying DifferentialGeometry &dg,
    const varying Ray &ray,
    uniform int64 flags)
{
  Ellipsoids *uniform self = (Ellipsoids * uniform) geometry;

  dg.Ng = dg.Ns = ray.Ng;

  vec3f radii = self->global_radii;
  if (valid(self->radii))
    radii = get_vec3f(self->radii, ray.primID);

  // make epsilon large enough to not get lost when computing
  // |CO| = |center-ray.org| ~ radius for 2ndary rays
  dg.epsilon = radii.x * ulpEpsilon;

  if (and(flags & DG_TEXCOORD, valid(self->texcoord)))
    dg.st = get_vec2f(self->texcoord, ray.primID);
}

unmasked void Ellipsoids_bounds(const RTCBoundsFunctionArguments *uniform args)
{
  Ellipsoids *uniform self = (Ellipsoids * uniform) args->geometryUserPtr;
  uniform int primID = args->primID;
  uniform vec3f radii = valid(self->radii) ? get_vec3f(self->radii, primID)
                                           : self->global_radii;
  uniform vec3f center = get_vec3f(self->vertex, primID);
  box3fa *uniform out = (box3fa * uniform) args->bounds_o;
  *out = make_box3fa(center - radii, center + radii);
}

void Ellipsoids_intersect_kernel(
    const RTCIntersectFunctionNArguments *uniform args,
    const uniform bool isOcclusionTest)
{
  // make sure to set the mask
  if (!args->valid[programIndex])
    return;

  Ellipsoids *uniform self = (Ellipsoids * uniform) args->geometryUserPtr;
  uniform int primID = args->primID;

  // this assumes that the args->rayhit is actually a pointer to a varying ray!
  varying Ray *uniform ray = (varying Ray * uniform) args->rayhit;

  uniform vec3f radii = valid(self->radii) ? get_vec3f(self->radii, primID)
                                           : self->global_radii;
  uniform vec3f center = get_vec3f(self->vertex, primID);

  const Intersections isect =
      intersectEllipsoid(ray->org, ray->dir, center, radii);

  // call intersection filtering callback and setup hit if accepted
  filterIntersectionBoth(args, isect, isOcclusionTest);
}

unmasked void Ellipsoids_intersect(
    const struct RTCIntersectFunctionNArguments *uniform args)
{
  Ellipsoids_intersect_kernel(args, false);
}


unmasked void Ellipsoids_occluded(
    const struct RTCOccludedFunctionNArguments *uniform args)
{
  Ellipsoids_intersect_kernel((RTCIntersectFunctionNArguments *)args, true);
}

inline vec3f uniformSampleEllipsoid(const vec3f radii, const vec2f s)
{
  const float phi = two_pi * s.x;
  const float cosTheta = radii.x * (1.f - 2.f * s.y);
  const float sinTheta = 2.f * radii.x * sqrt(s.y * (1.f - s.y));
  return cartesian(phi, sinTheta, cosTheta);
}

SampleAreaRes Ellipsoids_sampleArea(const Geometry *uniform const _self,
    const int32 primID,
    const uniform affine3f &xfm,
    const uniform affine3f &rcp_xfm,
    const vec2f &s)
{
  const Ellipsoids *const uniform self = (const Ellipsoids *uniform)_self;

  vec3f radii = self->global_radii;
  if (valid(self->radii))
    radii = get_vec3f(self->radii, primID);

  const vec3f localNormal = uniformSampleEllipsoid(radii, s);
  const vec3f localPos = get_vec3f(self->vertex, primID) + localNormal;

  SampleAreaRes res;
  res.pos = xfmPoint(xfm, localPos);
  res.normal = normalize(xfmVector(transposed(rcp_xfm.l), localNormal));

  return res;
}

void Ellipsoids_getAreas(const Geometry *const uniform _self,
    const int32 *const uniform primIDs,
    const uniform int32 numPrims,
    const uniform affine3f &xfm,
    float *const uniform areas)
{
  Ellipsoids *uniform self = (Ellipsoids * uniform) _self;

  // detect (non-uniform) scaling; get length of transformed unit-vectors
  const uniform vec3f scaling3 =
      make_vec3f(length(xfm.l.vx), length(xfm.l.vy), length(xfm.l.vz));
  const uniform float min_scaling = reduce_min(scaling3);
  const uniform float max_scaling = reduce_max(scaling3);
  if ((max_scaling - min_scaling) > 1e-4f * min_scaling)
    postStatusMsg(ISPC_MSG_SPHERES, OSP_LOG_WARNING);

  // use average as approximation to closest uniform scaling
  const uniform float scale = four_pi * sqr(reduce_add(scaling3) / 3.f);

  if (!valid(self->radii)) {

    const uniform float sphereArea = scale * sqr(self->global_radii.x);
    foreach (i = 0 ... numPrims)
      areas[i] = sphereArea;
  } else {
    // TODO vectorize this loop, with foreach or ProgramCount & ProgramIndex
    for (uniform int32 i = 0; i < numPrims; i++)
    {
      uniform vec3f radii = get_vec3f(self->radii, i);
      areas[i] = scale * sqr(radii.x);
    }
  }
}

void Ellipsoids_Constructor(Ellipsoids *uniform self)
{
  Geometry_Constructor(&self->super, Ellipsoids_postIntersect);
  self->super.getAreas = Ellipsoids_getAreas;
  self->super.sampleArea = Ellipsoids_sampleArea;
  Data1D_Constructor(&self->vertex);
  Data1D_Constructor(&self->radii);
  Data1D_Constructor(&self->texcoord);
  self->global_radii = make_vec3f(0.01, 0.02, 0.03);
}

export void *uniform Ellipsoids_create()
{
  Ellipsoids *uniform self = uniform new Ellipsoids;
  Ellipsoids_Constructor(self);
  return self;
}

export void EllipsoidsGeometry_set(void *uniform _self,
    void *uniform _embreeGeometry,
    const Data1D *uniform vertex,
    const Data1D *uniform radii,
    const Data1D *uniform texcoord,
    uniform vec3f &global_radii)
{
  Ellipsoids *uniform self = (Ellipsoids * uniform) _self;

  self->vertex = *vertex;
  self->radii = *radii;
  self->texcoord = *texcoord;
  self->global_radii = global_radii;
  self->super.numPrimitives = vertex->numItems;

  Geometry_setEmbreeUserGeometry(&self->super,
      (RTCGeometry)_embreeGeometry,
      Ellipsoids_bounds,
      Ellipsoids_intersect,
      Ellipsoids_occluded);
}
