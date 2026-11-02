import { Module } from '@nestjs/common';
import { TermiiModule } from '../termii/termii.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({ imports: [TermiiModule], controllers: [AuthController], providers: [AuthService] })
export class AuthModule {}
