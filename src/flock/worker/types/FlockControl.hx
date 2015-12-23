package flock.worker.types;

import js.html.Float32Array;
import net.rezmason.utils.workers.QuickBoss;

typedef FlockControl = QuickBoss<WorkerData, Float32Array>;
