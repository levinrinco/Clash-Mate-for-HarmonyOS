declare const entry: {
  version(): string;
  validate(config: string): string;
  setHome(dir: string): number;
  setLogPath(path: string): number;
  logTail(): string;
  start(config: string, tunFd: number, mode: string, logLevel: string, stack: string, mtu: number): number;
  stop(): number;
  lastError(): string;
};

export default entry;