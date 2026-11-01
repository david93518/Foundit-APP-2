import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : '伺服器內部錯誤';

    // 只記路徑不記查詢字串：/items 的查詢會帶使用者目前的經緯度，不該進日誌。
    const path = (request.originalUrl ?? request.url ?? '').split('?')[0];
    if (status >= 500) {
      this.logger.error(`${request.method} ${path} → ${status}`, exception instanceof Error ? exception.stack : '');
    } else {
      this.logger.warn(`${request.method} ${path} → ${status}`);
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      message: typeof message === 'object' ? (message as any).message : message,
      timestamp: new Date().toISOString(),
      path,
    });
  }
}
