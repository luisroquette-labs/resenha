#ifndef LogitTopK_h
#define LogitTopK_h

#include <stdint.h>

typedef struct {
    int32_t token_id;
    float logit;
} ResenhaLogitCandidate;

int32_t resenha_top_logits(
    const float *logits,
    int32_t count,
    int32_t limit,
    ResenhaLogitCandidate *output
);

#endif
