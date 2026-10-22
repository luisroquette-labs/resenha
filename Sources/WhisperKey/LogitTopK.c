#include "LogitTopK.h"

#include <math.h>

int32_t resenha_top_logits(
    const float *logits,
    int32_t count,
    int32_t limit,
    ResenhaLogitCandidate *output
) {
    if (logits == 0 || output == 0 || count <= 0 || limit <= 0) return 0;
    int32_t retained = 0;
    for (int32_t token_id = 0; token_id < count; token_id++) {
        const float logit = logits[token_id];
        if (!isfinite(logit)) continue;
        int32_t insertion = retained;
        while (insertion > 0 && output[insertion - 1].logit < logit) insertion--;
        if (insertion >= limit) continue;
        const int32_t end = retained < limit ? retained : limit - 1;
        for (int32_t index = end; index > insertion; index--) output[index] = output[index - 1];
        output[insertion] = (ResenhaLogitCandidate){token_id, logit};
        if (retained < limit) retained++;
    }
    return retained;
}
