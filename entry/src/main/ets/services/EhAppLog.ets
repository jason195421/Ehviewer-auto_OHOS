import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { ehSettingsStore } from './EhSettingsStore';

const LOG_FILE_NAME: string = 'ehviewer_app.log';
const MAX_LOG_BYTES: number = 512 * 1024;

export class EhAppLog {
  info(context: common.UIAbilityContext | undefined, tag: string, message: string): void {
    this.write(context, 'INFO', tag, message);
  }

  warn(context: common.UIAbilityContext | undefined, tag: string, message: string): void {
    this.write(context, 'WARN', tag, message);
  }

  error(context: common.UIAbilityContext | undefined, tag: string, message: string): void {
    this.write(context, 'ERROR', tag, message);
  }

  write(context: common.UIAbilityContext | undefined, level: string, tag: string, message: string): void {
    if (context === undefined || ehSettingsStore.getValue('save_crash_log', 'Off') !== 'On') {
      return;
    }
    const line = new Date().toISOString() + ' [' + level + '] ' + tag + ': ' + message + '\n';
    const path = this.logPath(context);
    let fd = -1;
    try {
      this.trimIfNeeded(path);
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.APPEND);
      fd = file.fd;
      fs.writeSync(fd, line);
    } catch (error) {
    } finally {
      if (fd >= 0) {
        try {
          fs.closeSync(fd);
        } catch (error) {
        }
      }
    }
  }

  read(context: common.UIAbilityContext): string {
    try {
      return fs.readTextSync(this.logPath(context));
    } catch (error) {
      return '';
    }
  }

  clear(context: common.UIAbilityContext): void {
    try {
      fs.unlinkSync(this.logPath(context));
    } catch (error) {
    }
  }

  logPath(context: common.UIAbilityContext): string {
    return context.filesDir + '/' + LOG_FILE_NAME;
  }

  size(context: common.UIAbilityContext): number {
    try {
      return fs.statSync(this.logPath(context)).size;
    } catch (error) {
      return 0;
    }
  }

  private trimIfNeeded(path: string): void {
    try {
      const stat = fs.statSync(path);
      if (stat.size <= MAX_LOG_BYTES) {
        return;
      }
      const text = fs.readTextSync(path);
      const keep = text.length > 200000 ? text.substring(text.length - 200000) : text;
      this.writeTextReplacing(path, keep);
    } catch (error) {
    }
  }

  private writeTextReplacing(path: string, text: string): void {
    let fd = -1;
    try {
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.READ_WRITE);
      fd = file.fd;
      fs.writeSync(fd, text);
    } catch (error) {
    } finally {
      if (fd >= 0) {
        try {
          fs.closeSync(fd);
        } catch (error) {
        }
      }
    }
  }
}

export const ehAppLog: EhAppLog = new EhAppLog();
