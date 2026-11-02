import {
  BadRequestException,
  HttpException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ResetTokenService } from '../common/reset-token.service';
import { normalizePhoneNumber, toLocalPhoneNumber } from '../common/phone.util';
import { SupabaseService } from '../supabase/supabase.service';
import { TermiiService } from '../termii/termii.service';

const RESET_PURPOSE = 'driver-password-reset';
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly supabase: SupabaseService,
    private readonly termii: TermiiService,
    private readonly resetTokens: ResetTokenService,
  ) {}

  async sendPhoneOtp(phone?: string) {
    const normalizedPhone = normalizePhoneNumber(phone);

    if (!normalizedPhone) {
      throw new BadRequestException('A valid phone number is required');
    }

    const pinId = await this.termii.sendOtp(normalizedPhone, 'Your Limpopo verification code is < 123456 >');
    return { success: true, pinId };
  }

  async verifyPhoneOtp(pinIdInput?: string, pinInput?: string) {
    const pinId = pinIdInput?.trim() ?? '';
    const pin = pinInput?.trim() ?? '';

    if (!pinId) {
      throw new BadRequestException('A valid OTP session is required');
    }

    if (!/^\d{6}$/.test(pin)) {
      throw new BadRequestException('Enter the 6-digit OTP code');
    }

    await this.termii.verifyOtp(pinId, pin);
    return { success: true, verified: true };
  }

  async createDriverAuthUser(body: Record<string, string | undefined>) {
    const firstName = body.firstName?.trim() ?? '';
    const lastName = body.lastName?.trim() ?? '';
    const email = body.email?.trim().toLowerCase() ?? '';
    const phone = body.phone?.trim() ?? '';
    const password = body.password?.trim() ?? '';
    const normalizedPhone = normalizePhoneNumber(phone);

    if (firstName.length < 3) throw new BadRequestException('First name must be at least 3 characters');
    if (lastName.length < 3) throw new BadRequestException('Last name must be at least 3 characters');
    if (!email || !EMAIL_PATTERN.test(email)) throw new BadRequestException('A valid email is required');
    if (!normalizedPhone) throw new BadRequestException('A valid phone number is required');
    if (password.length < 8) throw new BadRequestException('A temporary password is required');

    const { data, error } = await this.supabase.admin.auth.admin.createUser({
      email,
      phone: normalizedPhone,
      password,
      email_confirm: true,
      phone_confirm: true,
      user_metadata: {
        email,
        first_name: firstName,
        last_name: lastName,
        phone_num: phone,
        phone_verified: true,
        signup_complete: false,
      },
    });

    if (error || !data.user) {
      this.logger.warn(`failed to create auth user: ${error?.message}`);
      throw new BadRequestException(error?.message ?? 'Unable to create driver auth user');
    }

    return { success: true, userId: data.user.id };
  }

  async startPasswordReset(phone?: string) {
    const normalizedPhone = normalizePhoneNumber(phone);

    if (!normalizedPhone) {
      throw new BadRequestException('A valid phone number is required');
    }

    const localPhone = toLocalPhoneNumber(normalizedPhone);
    const { data: profile, error } = await this.supabase.admin
      .from('driver_profile')
      .select('uuid, phone_num')
      .eq('phone_num', localPhone)
      .maybeSingle<{ uuid: string; phone_num: string }>();

    if (error) {
      this.logger.error(`profile lookup failed: ${error.message}`);
      throw new InternalServerErrorException('Unable to start password reset right now');
    }

    if (!profile?.uuid) {
      throw new NotFoundException('No driver account exists for this phone number');
    }

    const pinId = await this.termii.sendOtp(normalizedPhone, 'Your Limpopo password reset code is < 123456 >');
    return { success: true, pinId, phone: localPhone };
  }

  async verifyPasswordResetOtp(body: { phone?: string; pinId?: string; otp?: string }) {
    const normalizedPhone = normalizePhoneNumber(body.phone);
    const pinId = body.pinId?.trim() ?? '';
    const otp = body.otp?.trim() ?? '';

    if (!normalizedPhone) throw new BadRequestException('A valid phone number is required');
    if (!pinId) throw new BadRequestException('A valid OTP session is required');
    if (!/^\d{6}$/.test(otp)) throw new BadRequestException('Enter the 6-digit OTP code');

    await this.termii.verifyOtp(pinId, otp);
    return { success: true, resetToken: this.resetTokens.issue(normalizedPhone, RESET_PURPOSE) };
  }

  async completePasswordReset(body: { phone?: string; resetToken?: string; password?: string }) {
    const normalizedPhone = normalizePhoneNumber(body.phone);
    const resetToken = body.resetToken?.trim() ?? '';
    const password = body.password?.trim() ?? '';

    if (!normalizedPhone) throw new BadRequestException('A valid phone number is required');
    if (!resetToken) throw new BadRequestException('A verified reset session is required');
    if (!/^\d{6}$/.test(password)) throw new BadRequestException('Create a 6-digit password to continue');

    this.resetTokens.assertValid(resetToken, normalizedPhone, RESET_PURPOSE);

    const localPhone = toLocalPhoneNumber(normalizedPhone);
    const admin = this.supabase.admin;
    const { data: profile, error: profileError } = await admin
      .from('driver_profile')
      .select('uuid')
      .eq('phone_num', localPhone)
      .maybeSingle<{ uuid: string }>();

    if (profileError) {
      this.logger.error(`profile lookup failed: ${profileError.message}`);
      throw new InternalServerErrorException('Unable to reset password right now');
    }

    if (!profile?.uuid) {
      throw new NotFoundException('No driver account exists for this phone number');
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(profile.uuid, {
      password,
      phone_confirm: true,
      user_metadata: { phone_num: localPhone, phone_verified: true },
    });

    if (updateError) {
      this.logger.warn(`auth update failed: ${updateError.message}`);
      throw new BadRequestException(updateError.message ?? 'Unable to update password');
    }

    const { error: syncError } = await admin.from('driver_profile').update({ phone_verified: true }).eq('uuid', profile.uuid);

    if (syncError) {
      this.logger.error(`profile update failed: ${syncError.message}`);
      throw new HttpException('Password updated but profile sync failed', 500);
    }

    return { success: true };
  }
}
