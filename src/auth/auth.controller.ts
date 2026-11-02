import { BadRequestException, Body, Controller, HttpCode, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('send-phone-otp')
  @HttpCode(200)
  sendPhoneOtp(@Body() body: { phone?: string } | null) {
    return this.auth.sendPhoneOtp(body?.phone);
  }

  @Post('verify-phone-otp')
  @HttpCode(200)
  verifyPhoneOtp(@Body() body: { pinId?: string; pin?: string } | null) {
    return this.auth.verifyPhoneOtp(body?.pinId, body?.pin);
  }

  @Post('create-driver-auth-user')
  @HttpCode(200)
  createDriverAuthUser(@Body() body: Record<string, string | undefined> | null) {
    return this.auth.createDriverAuthUser(body ?? {});
  }

  @Post('start-driver-password-reset')
  @HttpCode(200)
  startPasswordReset(@Body() body: { phone?: string } | null) {
    return this.auth.startPasswordReset(body?.phone);
  }

  @Post('verify-driver-password-reset-otp')
  @HttpCode(200)
  verifyPasswordResetOtp(@Body() body: { phone?: string; pinId?: string; otp?: string } | null) {
    return this.auth.verifyPasswordResetOtp(body ?? {});
  }

  @Post('complete-driver-password-reset')
  @HttpCode(200)
  completePasswordReset(@Body() body: { phone?: string; resetToken?: string; password?: string } | null) {
    return this.auth.completePasswordReset(body ?? {});
  }
}
