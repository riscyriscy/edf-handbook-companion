// SPDX-License-Identifier: GPL-2.0
/*
 * A dmaengine client for The Embedded AMD EDF Handbook, Chapter 6.
 * It takes the channel that its device tree node names "copy", copies a
 * buffer of random bytes with it, waits for the completion callback and
 * compares the two buffers. The calls are those of every dmaengine client:
 * request, prepare, submit, issue, wait, release.
 */
#include <linux/completion.h>
#include <linux/dma-mapping.h>
#include <linux/dmaengine.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/platform_device.h>
#include <linux/random.h>
#include <linux/string.h>

static unsigned int len = 65536;
module_param(len, uint, 0444);
MODULE_PARM_DESC(len, "Bytes to copy");

static void copy_done(void *arg)
{
	complete(arg);
}

static int dmacopy_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	DECLARE_COMPLETION_ONSTACK(done);
	struct dma_async_tx_descriptor *tx;
	enum dma_status status;
	dma_addr_t src_dma, dst_dma;
	struct dma_chan *chan;
	struct device *dmadev;
	dma_cookie_t cookie;
	void *src, *dst;
	int ret = 0;

	/* 1. The channel that the "dmas" and "dma-names" properties name */
	chan = dma_request_chan(dev, "copy");
	if (IS_ERR(chan))
		return dev_err_probe(dev, PTR_ERR(chan), "no channel named copy\n");
	dmadev = chan->device->dev;
	dev_info(dev, "channel %s of %s, memcpy %s\n", dma_chan_name(chan), dev_name(dmadev),
		 dma_has_cap(DMA_MEMCPY, chan->device->cap_mask) ? "yes" : "no");

	/* 2. Buffers that the DMA controller can reach: allocate them for its device */
	src = dma_alloc_coherent(dmadev, len, &src_dma, GFP_KERNEL);
	dst = dma_alloc_coherent(dmadev, len, &dst_dma, GFP_KERNEL);
	if (!src || !dst) {
		ret = -ENOMEM;
		goto out;
	}
	get_random_bytes(src, len);
	memset(dst, 0, len);

	/* 3. Prepare, set the callback, submit, and start the queue */
	tx = dmaengine_prep_dma_memcpy(chan, dst_dma, src_dma, len,
				       DMA_PREP_INTERRUPT | DMA_CTRL_ACK);
	if (!tx) {
		dev_err(dev, "prep failed\n");
		ret = -EIO;
		goto out;
	}
	tx->callback = copy_done;
	tx->callback_param = &done;
	cookie = dmaengine_submit(tx);
	if (dma_submit_error(cookie)) {
		ret = -EIO;
		goto out;
	}
	dma_async_issue_pending(chan);

	/* 4. Wait, and stop the channel if the transfer never ends */
	if (!wait_for_completion_timeout(&done, msecs_to_jiffies(1000))) {
		dev_err(dev, "timeout\n");
		dmaengine_terminate_sync(chan);
		ret = -ETIMEDOUT;
		goto out;
	}
	status = dma_async_is_tx_complete(chan, cookie, NULL, NULL);
	dev_info(dev, "copied %u bytes: status %s, data %s\n", len,
		 status == DMA_COMPLETE ? "complete" : "error",
		 memcmp(src, dst, len) ? "differs" : "matches");
out:
	if (dst)
		dma_free_coherent(dmadev, len, dst, dst_dma);
	if (src)
		dma_free_coherent(dmadev, len, src, src_dma);
	/* 5. Give the channel back */
	dma_release_channel(chan);
	return ret;
}

static const struct of_device_id dmacopy_of_match[] = {
	{ .compatible = "handbook,dma-copy" },
	{ }
};
MODULE_DEVICE_TABLE(of, dmacopy_of_match);

static struct platform_driver dmacopy_driver = {
	.probe = dmacopy_probe,
	.driver = {
		.name = "handbook-dmacopy",
		.of_match_table = dmacopy_of_match,
	},
};
module_platform_driver(dmacopy_driver);
MODULE_DESCRIPTION("dmaengine memcpy client of the EDF handbook");
MODULE_LICENSE("GPL");
