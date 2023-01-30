// Copyright 2009 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

#include "SphHarm.ih"
#include "common/World.ih"
#include "math/random.ih"
#include "math/sampling.ih"
#include "surfaces.ih"
#include "volume/VolumetricModel.ih"
#include "volumes.ih"
// c++ shared
#include "fb/FrameBufferShared.h"

struct SHIntersections
{
  unsigned int numIntersections;
  float roots[10];
  vec3f normals[10];
};

inline void traceSHRay(
    const World *uniform world, varying Ray &ray, varying SHIntersections &hitData)
{
  /* if (!world->embreeSceneHandleVolumes) */
  /*   return; */

  uniform EmbreeIntersectionContext context;
  rtcInitIntersectContext(&context.ectx);
  context.userPtr = &hitData;
  rtcIntersectV(world->embreeSceneHandleGeometries, &context.ectx, (varying RTCRayHit * uniform) & ray);

  /* if (intervals.numSHIntervals > 0) { */
    /* for (uniform int i = 0; i < intervals.numSHIntervals; ++i) { */
      /* const Instance *const instance = */
          /* *(world->instances + intervals.intervals[i].instID); */
      /* intervals.intervals[i].instance = instance; */
      /* intervals.intervals[i].bbox = instance->group->getBounds(); */
    /* } */
  /* } */
}

inline void traceSHRayIntervals(const World *uniform world,
    varying Ray &ray,
    varying RayIntervals &rayIntervals,
    varying SHIntersections &hitData)
{
  // Save the ray
  const float t0 = ray.t0;
  const float t = ray.t;

  // Iterate through ray intervals
  for (uint32 i = 0; i < rayIntervals.count; i++) {
    // Set ray interval
    ray.t0 = rayIntervals.intervals[i].lower;
    ray.t = rayIntervals.intervals[i].upper;

    // Skip intervals outside of the ray range
    if (or (t < ray.t0, ray.t < t0))
      continue;

    // Clip interval to the ray range
    ray.t0 = max(ray.t0, t0);
    ray.t = min(ray.t, t);

    // Shoot the ray
    traceSHRay(world, ray, hitData);

    // Exit loop if geometry hit
    if (hadHit(ray)) {
      ray.t0 = t0;
      return;
    }
  }

  // Restore the ray
  ray.t0 = t0;
  ray.t = t;
}

void SphHarm_renderSample(Renderer *uniform _self,
    FrameBuffer *uniform fb,
    World *uniform world,
    void *uniform perFrameData,
    varying ScreenSample &sample)
{
  uniform SphHarm *uniform self = (uniform SphHarm * uniform) _self;

  LDSampler ldSamplerObj;
  varying LDSampler *uniform ldSampler = &ldSamplerObj;
  LDSampler_init(ldSampler,
      sample.sampleID.x + fb->size.x * sample.sampleID.y,
      sample.sampleID.z);

  uniform bool firstHit = true;
  bool allHitsFullyTransmissive = true;
  const float originalRayTFar = sample.ray.t;

  // Allocate memory for volume intervals
  /* VolumeIntervals volumeIntervals; */
  /* allocVolumeIntervals(volumeIntervals); */

  // This is our main ray
  Ray &ray = sample.ray;

  // First trace the ray across clipping scene to calculate ray intervals,
  // this step should keep ray structure unchanged
  /* RayIntervals rayIntervals; */
  /* traceClippingRay(world, ray, rayIntervals); */

  // Iterate over all translucent geometry till we are fully opaque
  float A_src = 1.0;
  float A_dst = 1.0;
  vec3f outColor = make_vec3f(0.f);
  /* vec3f outTransmission = make_vec3f(1.f); */
  /* int minVolIndex = 0; // interval index of closest volume */
  SHIntersections hitData;
  hitData.numIntersections = 0;
  /* traceSHRay(world, ray, hitData); */
  /* traceSHRayIntervals(world, ray, rayIntervals, hitData); */
  traceSHRay(world, ray, hitData);

  for (int i = 0; i < hitData.numIntersections; ++i) {
  /* while (true) { */
    // Then trace normal geometry using calculated ray intervals,
    // if hit ray.t will be updated
    /* traceGeometryRayIntervals(world, ray, rayIntervals); */

    // Determine volume intervals by tracing ray in the volume scene
    /* Ray volumeRay = ray; */
    /* traceVolumeRay(world, volumeRay, volumeIntervals); */
    /* hitData.numIntersections = 0; */
    /* traceSHRay(world, ray, hitData); */
    /* print("hits: %\n", hitData.numIntersections); */

    // Sample volumes across volume intervals (in front of geometry hit)
    /* if (volumeIntervals.numVolumeIntervals > 0) { */
    /*   SphHarmRenderContext rc; */
    /*   rc.renderer = self; */
    /*   rc.fb = fb; */
    /*   rc.world = world; */
    /*   rc.sample = sample; */
    /*   rc.ldSampler = ldSampler; */
    /*   volumeRay.geomID = RTC_INVALID_GEOMETRY_ID; */
    /*   vec4f volumeColor = integrateVolumeIntervalsGradient(rc, */
    /*       volumeIntervals, */
    /*       rayIntervals, */
    /*       volumeRay, */
    /*       ldSampler, */
    /*       self->volumeSamplingRate, */
    /*       true); */

    /*   // Blend volume */
    /*   outColor = outColor + outTransmission * make_vec3f(volumeColor); */
    /*   outTransmission = outTransmission * volumeColor.w; */

    /*   if (hadHit(volumeRay) && sample.geomID == RTC_INVALID_GEOMETRY_ID) { */
    /*     sample.primID = 0; */
    /*     foreach_unique (instID in volumeRay.instID) */
    /*       if (instID != RTC_INVALID_GEOMETRY_ID) { */
    /*         const Instance *uniform instance = *(world->instances + instID); */
    /*         sample.instID = (instance->userID == RTC_INVALID_GEOMETRY_ID) */
    /*             ? instID */
    /*             : instance->userID; */
    /*         const VolumetricModel *volms = */
    /*             *(instance->group->volumetricModels + volumeRay.geomID); */
    /*         foreach_unique (volm in volms) */
    /*           sample.geomID = (volm->userID == RTC_INVALID_GEOMETRY_ID) */
    /*               ? volumeRay.geomID */
    /*               : volm->userID; */
    /*       } */
    /*   } */
    /* } */

    if (dot(hitData.normals[i], ray.dir) > 0)
      hitData.normals[i] = neg(hitData.normals[i]);

    // Add contribution from visible lights, P is used by light
    // evaluation
    DifferentialGeometry dg;
    dg.P = dg.lP = ray.org + hitData.roots[i] * ray.dir;
    dg.Ng = dg.Ns = hitData.normals[i];
    dg.color = make_vec4f(1);
    /* dg.color = make_vec4f(dg.Ng.x, dg.Ng.y, dg.Ng.z, 1); */
    dg.color = make_vec4f(hitData.roots[1], hitData.roots[2], hitData.roots[3], 1);
    dg.primID = ray.primID;
    dg.material = NULL;

    /* if (self->visibleLights) { */
      /* dg.P = ray.org; */
      /* outColor = outColor + outTransmission * evaluateLights(world, dg, ray); */
    /* } */
    ray.t = hitData.roots[i];
    ray.Ng = hitData.normals[i];
    SSI ssi = computeShading(self, fb, world, dg, sample, ldSampler, ray.dir);
    vec3f color = ssi.shadedColor;
    color.x = hitData.roots[1];
    color.y = hitData.roots[2];
    color.z = hitData.roots[3];

    // If any geometry has been hit
    /* const bool hadHit = true; */
    /* if (hadHit) { */
      // Prepare differential geometry structure
      /* postIntersect(world, */
          /* &self->super, */
          /* dg, */
          /* ray, */
          /* DG_NG | DG_NS | DG_NORMALIZE | DG_FACEFORWARD | DG_COLOR */
              /* | DG_TEXCOORD); */

      // Shade geometry
      /* SSI surfaceShading; */
      /* surfaceShading = */
          /* computeShading(self, fb, world, dg, sample, ldSampler, ray.dir); */

      // Initialize other per sample data with first hit values
      // In addition to considering the first hit, all previous, fully
      // transmissive hits will lead the normal/albedo to be replaced by the
      // current hit
      /* if (firstHit || allHitsFullyTransmissive) { */
      /*   sample.z = min(ray.t, volumeRay.t); */
      /*   sample.albedo = surfaceShading.albedo; */
      /*   sample.normal = dg.Ns; */
      /*   if (sample.geomID == RTC_INVALID_GEOMETRY_ID) { */
      /*     sample.instID = dg.instID; */
      /*     sample.geomID = dg.objID; */
      /*     sample.primID = ray.primID; */
      /*   } */
      /*   firstHit = false; */
      /* } */

      // A sequence of hits is considered fully transparent if it's total
      // normalized transmission is close to 1.0f and all previous hits were
      // fully transmissive
      /* allHitsFullyTransmissive = allHitsFullyTransmissive */
          /* && surfaceShading.opacity < self->super.minContribution; */

      // Blend with output final color
      outColor = A_dst*(A_src*color) + outColor;
      /* outColor = color; */
      A_dst *= (1-A_src);
      /* outColor = outColor + outTransmission * surfaceShading.shadedColor; */
      /* outTransmission = outTransmission * surfaceShading.transmission; */

      // Early exit if remaining transmission is below min contribution
      // threshold
      /* if (luminance(outTransmission) < self->super.minContribution) { */
        /* outTransmission = make_vec3f(0.f); */
        /* break; */
      /* } */

      // Prepare ray for next loop iteration,
      // start from the last geometry hit all over to initial Tfar
      /* setRay(ray, ray.t + dg.epsilon, originalRayTFar); */
    /* } else { */
      // Blend background with output final color
      /* vec4f backgroundColor = Renderer_getBackground(&self->super, sample.pos); */
      /* vec4f backgroundColor = make_vec4f(1,0,0,1); */
      /* outColor = outColor + outTransmission * make_vec3f(backgroundColor); */
      /* outTransmission = outTransmission * (1.f - backgroundColor.w); */

      // Initialize other per sample data with first hit values
      // If the ray hits the background and comes from a fully transmissive
      // path, we overwrite normals/albedo by background values
      /* if (firstHit || allHitsFullyTransmissive) { */
        /* sample.z = min(ray.t, volumeRay.t); */
        /* sample.albedo = make_vec3f(backgroundColor); // TODO volume albedo */
        /* sample.normal = make_vec3f(0.f); */
      /* } */

      // No more intersections
      /* break; */
    /* } */
  }

  /* if (hitData.numIntersections > 0) outColor = make_vec3f(hitData.numIntersections*.1); */
  /* freeVolumeIntervals(volumeIntervals); */
  sample.rgb = outColor;
  /* sample.alpha = 1.f - luminance(outTransmission); */
  sample.alpha = A_dst;
}

vec3f SphHarm_computeAO(const uniform SphHarm *uniform self,
    const FrameBuffer *uniform fb,
    const World *uniform world,
    ScreenSample &sample,
    varying LDSampler *uniform ldSampler,
    const varying DifferentialGeometry &dg,
    const uniform int sampleCnt,
    const uniform float aoRadius,
    const varying vec3i &sampleID)
{
  const uniform int accumID = reduce_max(sampleID.z) * sampleCnt;

  // init TEA RNG //
  RandomTEA rng_state;
  varying RandomTEA *const uniform rng = &rng_state;
  RandomTEA__Constructor(rng, sampleID.x, sampleID.y);
  const vec2f rot = RandomTEA__getFloats(rng);

  vec3f hits = make_vec3f(0.f);

  const linear3f localToWorld = frame(dg.Ns);

  for (uniform int i = 0; i < sampleCnt; i++) {
    // Use base-5 and base-7 Halton to avoid correlation with sample position
    const vec2f halton = make_vec2f(
        PermHalton_sample5(accumID + i), PermHalton_sample7(accumID + i));
    const vec2f r = CranleyPattersonRotation(halton, rot);
    const vec3f local_ao_dir = cosineSampleHemisphere(r);
    const vec3f ao_dir = localToWorld * local_ao_dir;

    if (dot(ao_dir, dg.Ns) < 0.01f) { // check below surface
      hits = hits + make_vec3f(1.f);
      continue;
    }

    Ray ao_ray;
    setRay(ao_ray, dg.P, ao_dir, dg.epsilon, aoRadius);

    hits = hits
        + (1.f
            - lightAlpha(self,
                ao_ray,
                fb,
                world,
                sample,
                ldSampler,
                make_vec3f(1.f),
                dg.epsilon,
                0.1f));
  }

  // the cosTheta of cosineSampleHemispherePDF and dot(shadingNormal, ao_dir)
  // cancel
  return 1.0f - (hits / (float)sampleCnt);
}

// SphHarm C++ interface /////////////////////////////////////////////////////

export void *uniform SphHarm_renderSample_addr()
{
  return SphHarm_renderSample;
}
