import native from 'libentry.so';

export class Mihomo {
  static version(): string {
    try {
      return native.version();
    } catch (error) {
      return `ERR ${(error as Error).message}`;
    }
  }

  static validate(config: string): string {
    try {
      return native.validate(config);
    } catch (error) {
      return `ERR ${(error as Error).message}`;
    }
  }

  static setHome(dir: string): number {
    try {
      return native.setHome(dir);
    } catch (error) {
      return -1;
    }
  }

  static setLogPath(path: string): number {
    try {
      return native.setLogPath(path);
    } catch (error) {
      return -1;
    }
  }

  static logTail(): string {
    try {
      return native.logTail();
    } catch (error) {
      return `ERR ${(error as Error).message}`;
    }
  }

  static start(config: string, tunFd: number, mode: string, logLevel: string, stack: string,
    mtu: number): number {
    try {
      return native.start(config, tunFd, mode, logLevel, stack, mtu);
    } catch (error) {
      return -1;
    }
  }

  static stop(): number {
    try {
      return native.stop();
    } catch (error) {
      return -1;
    }
  }

  static lastError(): string {
    try {
      return native.lastError();
    } catch (error) {
      return `ERR ${(error as Error).message}`;
    }
  }
}